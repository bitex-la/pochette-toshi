# PochetteToshi

A [Pochette](https://github.com/bitex-la/pochette) backend using Toshi.

It will connect to your Toshi postgres database directly (not using Toshi's JSON RPC)

Transactions will be pushed through bitcoin

For better performance it is recommended you create the following indexes in your
database:

```sql
CREATE INDEX inputs_hsh_index on inputs (hsh);
CREATE INDEX inputs_is_coinbase_index on inputs (prev_out, hsh) WHERE prev_out = '0000000000000000000000000000000000000000000000000000000000000000';
CREATE INDEX unspent_outputs_usable_index on unspent_outputs (amount) WHERE amount > 5000;
CREATE INDEX transactions_hsh_height ON transactions (hsh, height);
```

You can instatiate a Toshi backend passing your postgres connection options, they will be passed
to the pg gem [as seen in their docs](http://deveiate.org/code/pg/PG/Connection.html#method-c-new)

```ruby
>>> Pochette::Backends::Toshi.new(host: 'your-db-host', dbname: 'toshi')
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pochette_toshi'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pochette_toshi

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`,
and then run `bundle exec rake release` to create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/pochette_toshi/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
