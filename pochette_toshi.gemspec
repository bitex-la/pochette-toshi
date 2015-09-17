# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pochette_toshi/version'

Gem::Specification.new do |spec|
  spec.name          = "pochette_toshi"
  spec.version       = PochetteToshi::VERSION
  spec.authors       = ["Nubis"]
  spec.email         = ["yo@nubis.im"]

  spec.summary       = %q{Toshi backend for pochette }
  spec.homepage      = "https://github.com/bitex-la/pochette-toshi"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]
  spec.add_dependency "pochette"
  spec.add_dependency "pg"
  spec.add_dependency "activesupport", "> 4.2.0"

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 2"
end
