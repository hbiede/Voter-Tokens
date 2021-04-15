# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.2
# License:

require 'test/unit'
require 'simplecov'
SimpleCov.start

require_relative '../gen_tokens'
require_relative '../vote_parser'

if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end
