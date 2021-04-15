# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.2
# License:

require 'test-unit'
require 'simplecov'
SimpleCov.start do
  add_filter '/tests/'
end

Test::Unit::AutoRunner.run(true, File.dirname(__FILE__))

if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
else
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
end
