$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pochette_toshi'
require 'webmock/rspec'
RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:expect, :should]
  end
  config.mock_with :rspec do |c|
    c.syntax = [:expect, :should]
  end
end

