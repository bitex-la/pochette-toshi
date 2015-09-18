require "pochette_toshi/version"
require "active_support"
require "active_support/core_ext"
require "pg"
require 'pochette'

# This class is not properly tested.
# Be careful when changing anything, and/or make sure
# you can run and assert your changes with a local copy of
# a toshi testnet database.
class Pochette::Backends::Toshi 
  attr_accessor :connection

  def initialize(options)
    self.connection = PG.connect(options)
  end
  
  def incoming_for(addresses, min_date)
    addresses.in_groups_of(500, false).collect do |group|
      incoming_for_helper(group, min_date)
    end.flatten(1)
  end

  def incoming_for_helper(addresses, min_date)
    addresses_sql = sanitize_list(addresses)
    current_height = block_height
    from_block = current_height - ((Time.now - min_date) / 60 / 60 * 6).ceil

    query(%{
      SELECT ale.amount, a.address, t.hsh,
        (#{current_height + 1} - t.height) as confirmations, o.position,
        (SELECT string_agg(a2.address,',') as sender
         FROM address_ledger_entries ale2
           INNER JOIN addresses a2 ON a2.id = ale2.address_id
         WHERE ale2.transaction_id = t.id AND ale2.input_id IS NOT NULL
        ) as senders
      FROM address_ledger_entries ale
        INNER JOIN addresses a ON a.id = ale.address_id AND a.address in (#{addresses_sql})
        INNER JOIN transactions t ON t.id = ale.transaction_id AND t.pool = 1 AND t.height > #{from_block}
        INNER JOIN outputs o ON o.id = ale.output_id AND o.branch = 0
      UNION
      SELECT ale.amount, a.address, t.hsh, 0 as confirmations, o.position,
        (
         SELECT string_agg(a2.address,',') as sender
         FROM unconfirmed_ledger_entries ale2
           INNER JOIN unconfirmed_addresses a2 ON a2.id = ale2.address_id
         WHERE ale2.transaction_id = t.id AND ale2.input_id IS NOT NULL
        ) as senders
      FROM unconfirmed_ledger_entries ale
        INNER JOIN unconfirmed_addresses a ON a.id = ale.address_id AND a.address in (#{addresses_sql})
        INNER JOIN unconfirmed_transactions t ON t.id = ale.transaction_id AND t.pool = 1
        INNER JOIN unconfirmed_outputs o ON o.id = ale.output_id 
    }).collect{|a,addr,hsh,confs,pos,sender| [a.to_i, addr, hsh, confs.to_i, pos.to_i, sender] }
  end
  
  def balances_for(addresses, confirmations)
    addresses.in_groups_of(500, false).reduce({}) do |accum, group|
      accum.merge!(balances_for_helper(group, confirmations))
    end
  end

  def balances_for_helper(addresses, confirmations)
    # Addresses have denormalized sent and received columns for all
    # transactions. We must then calculate which portion
    # of that is unconfirmed in order to get the 'confirmed' balances.
    # And to get the 'unconfirmed' balances we also need to fetch
    # ledger entries for transactions that were not added to a block yet.
    addresses_sql = sanitize_list(addresses)
    
    confirmed_id_to_address = {}
    unconfirmed_id_to_address = {}
    result = addresses.reduce({}) do |accum, address|
      accum[address] = [0,0,0,0,0,0]
      accum
    end

    query(%{
      SELECT id, address, total_received, total_sent
      FROM addresses WHERE address in (#{addresses_sql})
    }).each do |id, address, received, sent|
      confirmed_id_to_address[id] = address
      received = received.to_d / 1_0000_0000
      sent = sent.to_d / 1_0000_0000
      balance = received - sent
      result[address] = [received, sent, balance, received, sent, balance]
    end

    # Now we take the previous 1 confirmation balances and substract
    # what was below threshold to get the 'confirmed' balances.
    query(%{
      SELECT ale.address_id,
        sum(CASE WHEN ale.amount > 0 THEN ale.amount ELSE 0 END) as received,
        sum(CASE WHEN ale.amount < 0 THEN ale.amount ELSE 0 END) as sent
      FROM address_ledger_entries ale
        INNER JOIN addresses a ON a.id = ale.address_id AND a.address in (#{addresses_sql})
        INNER JOIN transactions t ON t.id = ale.transaction_id AND t.pool = 1
          AND t.height > #{block_height - confirmations + 1}
      GROUP BY ale.address_id
    }).each do |id, received, sent|
      row = result[confirmed_id_to_address[id]]
      row[0] = row[0] - (received.to_d / 1_0000_0000)
      row[1] = row[1] - (sent.to_d.abs / 1_0000_0000)
      row[2] = row[0] - row[1]
    end

    query(%{SELECT id, address
      FROM unconfirmed_addresses WHERE address in (#{addresses_sql})
    }).each do |id, address|
      unconfirmed_id_to_address[id] = address
    end
    
    # And then we also add the unconfirmed stuff to the already
    # cached 1 confirmation balances
    query(%{
      SELECT ale.address_id, 
        sum(CASE WHEN ale.amount > 0 THEN ale.amount ELSE 0 END) as received,
        sum(CASE WHEN ale.amount < 0 THEN ale.amount ELSE 0 END) as sent
      FROM unconfirmed_ledger_entries ale
        INNER JOIN unconfirmed_addresses a ON a.id = ale.address_id
          AND a.address in (#{addresses_sql})
        INNER JOIN unconfirmed_transactions t ON t.id = ale.transaction_id AND t.pool = 1
      GROUP BY ale.address_id
    }).each do |id, received, sent|
      row = result[unconfirmed_id_to_address[id]]
      row[3] += (received.to_d / 1_0000_0000)
      row[4] += (sent.to_d.abs / 1_0000_0000)
      row[5] = row[3] - row[4]
    end
    
    return result 
  end

  # Performs the low level queries to the toshi database
  # and returns a JSON structure for the unspents and the transactions.
  # THIS METHOD IS NOT TESTED IN CI!!!! DO NOT JUST REFACTOR THIS WITHOUT
  # TESTING IT LOCALLY AGAINST THE ~20 GB TOSHI TESTNET DATABASE.
  def list_unspent(addresses)
    unspents = []
    addresses.in_groups_of(500, false).collect do |group|
      unspents += list_unspent_helper(group)
    end
    unspents
  end

  def list_unspent_helper(addresses)
    addresses_sql = sanitize_list(addresses)
    query(%{
      SELECT a.address, o.hsh, o.position, uo.amount
      FROM addresses a
        INNER JOIN unspent_outputs uo ON uo.address_id = a.id AND uo.amount > 5000
        LEFT JOIN outputs o ON o.id = uo.output_id
      WHERE a.address in (#{addresses_sql})
        AND NOT EXISTS (
          SELECT i.id FROM inputs i
          LEFT JOIN transactions t ON t.hsh = i.hsh
          WHERE i.hsh = o.hsh AND
          i.prev_out = '0000000000000000000000000000000000000000000000000000000000000000'
          AND t.height > #{block_height - 100}
        )
    }).collect{|a,b,c,d| [a,b,c.to_i,d.to_i]}
  end

  def list_transactions(txids)
    transactions = []
    addresses.in_groups_of(500, false).collect do |group|
      transactions += list_transactions_helper(group)
    end
    transactions
  end

  def list_transactions_helper(hashes)
    transactions_sql = sanitize_list(hashes)
    transactions = query(%{SELECT * FROM transactions WHERE hsh IN (#{transactions_sql})})
    inputs = query(%{SELECT * FROM inputs WHERE hsh IN (#{transactions_sql})
      ORDER BY position})
    inputs_by_hsh = inputs.reduce({}) do |d, i|
      d[i[1]] ||= []
      d[i[1]] << i
      d
    end
    outputs = query(%{SELECT * FROM outputs WHERE hsh IN (#{transactions_sql})
      ORDER BY position})
    outputs_by_hsh = outputs.reduce({}) do |d, o|
      d[o[1]] ||= []
      d[o[1]] << o
      d
    end
    
    transactions_json = transactions.collect do |_, hsh, ver, lock_time|
      inputs_json = inputs_by_hsh[hsh].collect do |_, _, prev, index, script, seq, pos|
        { prev_hash: prev,
          prev_index: index.to_i,
          sequence: [seq[2..-1]].pack('H*').unpack('V')[0],
          script_sig: script[2..-1]
        }
      end
      outputs_json = outputs_by_hsh[hsh].collect do |_, _, amount, script|
        { amount: amount.to_i, script_pubkey: script[2..-1] }
      end
      { hash: hsh,
        version: ver.to_i,
        lock_time: lock_time.to_i,
        inputs: inputs_json,
        bin_outputs: outputs_json
      }
    end
    transactions_json
  end

  def block_height
    connection.exec('select max(height) from blocks where branch = 0').values[0][0].to_i
  end
  
  def query(sql)
    connection.exec(sql).values
  end
  
  def sanitize_list(list)
    list.collect{|a| "'#{a}'"}.join(',')
  end
end

