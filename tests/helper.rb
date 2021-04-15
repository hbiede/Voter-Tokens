# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.2
# License: MIT
require 'test/unit'
require 'simplecov'
SimpleCov.start

if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end
