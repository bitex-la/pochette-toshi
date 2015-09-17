require 'spec_helper'

describe PochetteToshi do
  it 'has a version number' do
    expect(PochetteToshi::VERSION).not_to be nil
  end

  # Toshi is supposed to be a thin wrapper that just
  # makes very specific queries.
  # In order to test it properly you would need to have
  # an instance of toshi running locally.
  # It's ok to comment this test out once we're done running
  # them locally, as we do not need to connect to a toshi db
  # from the CI server.
  let(:addresses){
    ['mhLAgRz5f1YogfYBZCDFSRt3ceeKBPVEKg', # Receives in more than one position in the same tx
    '2MvvYhnJEWJmL41nfeguFz1J6xBUYLmM3pA', # Same as above. (I think)
    'n1UUe8EBaXX5SDkJpjMzKCnZGYJJ7pdjF6', # Has transactions with only 1 confirmation
    'mrx2KEsQNu75t1fyA5AKoH2FYn6VzaQZ7K', # Is only in unconfirmed_addresses
    '2MzRBk5wLWtw85zFbj3Ky6XJYhfCHvcXUeB' # Is both in unconfirmed and confirmed
    ]
  }

  let(:backend){ Pochette::Backends::Toshi.new(user: 'toshi', dbname: 'toshi_development') }

  def query(sql)
    Toshi.connection.execute(sql).values[0]
  end

  #it 'lists all transactions for a group of addresses' do
  #  print JSON.pretty_generate JSON.parse backend.incoming_for(addresses, 3.years.ago).to_json
  #end

  #it 'lists unspent outputs' do
  #  print JSON.pretty_generate JSON.parse Toshi.list_unspent(addresses)[1].to_json
  #end
  ##
  #it 'lists confirmed and unconfirmed balances for a set of addresses' do
  #  print JSON.pretty_generate JSON.parse Toshi.balances_for(addresses, 1).to_json
  #end
  # 
  #it 'lists all unspent outputs and transactions for the given address' do
  #  has_unspent_recent_block_reward, unspent_recent_block_reward = query %{
  #    SELECT a.address, t.hsh FROM inputs i
  #    JOIN outputs o ON o.hsh = i.hsh
  #    JOIN transactions t ON t.hsh = i.hsh AND t.height = ((select max(height) from blocks) - 50)
  #    JOIN unspent_outputs uo ON uo.output_id = o.id
  #    JOIN addresses a ON a.id = uo.address_id
  #    WHERE i.prev_out = '0000000000000000000000000000000000000000000000000000000000000000' limit 1}

  #  has_unspent_old_block_reward, unspent_old_block_reward = query %{
  #    SELECT a.address, t.hsh FROM inputs i
  #    JOIN outputs o ON o.hsh = i.hsh
  #    JOIN transactions t ON t.hsh = i.hsh AND t.height = ((select max(height) from blocks) - 150)
  #    JOIN unspent_outputs uo ON uo.output_id = o.id
  #    JOIN addresses a ON a.id = uo.address_id
  #    WHERE i.prev_out = '0000000000000000000000000000000000000000000000000000000000000000' limit 1}

  #  id_for_spent_and_unspent_address = query(%{SELECT ale.address_id FROM address_ledger_entries ale
  #    INNER JOIN addresses a ON ale.address_id = a.id
  #      AND ((a.total_received - a.total_sent) > 50000000)
  #    GROUP BY ale.address_id
  #    HAVING count(ale.input_id) > 1 and count(ale.output_id) > 1 limit 1})[0]

  #  has_unspent_and_spent = query(%{
  #    SELECT address FROM addresses WHERE id = #{id_for_spent_and_unspent_address}
  #  })[0]

  #  a_spent_output = query(%{SELECT o.hsh FROM outputs o
  #    INNER JOIN address_ledger_entries ale ON ale.output_id = o.id
  #    INNER JOIN addresses a ON ale.address_id = a.id AND a.address = '#{has_unspent_and_spent}'
  #    WHERE o.spent = true limit 1})[0]

  #  an_unspent_output = query(%{SELECT o.hsh FROM outputs o
  #    INNER JOIN address_ledger_entries ale ON ale.output_id = o.id
  #    INNER JOIN addresses a ON ale.address_id = a.id AND a.address = '#{has_unspent_and_spent}'
  #    WHERE o.spent = false limit 1})[0]

  #  has_spent_it_all = query(%{SELECT address FROM addresses
  #    WHERE total_received = total_sent AND total_received > 50000000000 limit 1})[0]
  #  
  #  has_unspent_dust_only = query(%{SELECT string_agg(a.address,'') FROM unspent_outputs uo
  #    LEFT JOIN addresses a ON a.id = uo.address_id GROUP BY uo.address_id
  #    HAVING count(*) = 1 AND sum(amount) < 5000 AND sum(amount) > 1000 limit 1})[0]
  #  
  #  addresses = [
  #    has_unspent_recent_block_reward,
  #    has_unspent_old_block_reward,
  #    has_unspent_and_spent,
  #    has_spent_it_all,
  #    has_unspent_dust_only
  #  ]
  #  
  #  unspents, transactions = Toshi.list_unspent(addresses)
  #  
  #  # Addresses without unspent outputs do not show up, obviously.
  #  unspents.collect(&:first).uniq.should_not include(has_spent_it_all)
  #  
  #  # A block reward with less than 100 confirmations should not be spendable yet.
  #  unspents.find{|_, hsh, _| hsh == unspent_recent_block_reward }.should be_nil
  #  
  #  # A block reward with more than 100 confirmation can be spent.
  #  unspents.find{|_, hsh, _| hsh == unspent_old_block_reward }.should_not be_nil
  #  
  #  # This address has spent and unspent outputs, we make sure only the unspent
  #  # ones appear in the result list.
  #  unspents.find do |address, hsh, position|
  #    address == has_unspent_and_spent &&
  #    hsh == an_unspent_output
  #  end.should_not be_nil
  #  unspents.find do |address, hsh, position|
  #    address == has_unspent_and_spent &&
  #    hsh == a_spent_output
  #  end.should be_nil

  #  # Outputs with only dust in them should not be listed.
  #  unspents.find do |address, hsh, position|
  #    address == has_unspent_dust_only
  #  end.should be_nil
  #end
end
