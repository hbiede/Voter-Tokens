# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.2
# License:

require 'test-unit'
require 'simplecov'
SimpleCov.start do
  add_filter '/tests/'
  enable_coverage :branch
end

def disable_stderr
  orig_stderr = $stderr.clone
  $stderr = File.new(File::NULL, 'w')

  yield
ensure
  $stderr = orig_stderr
end

disable_stderr do
  Test::Unit::AutoRunner.run(true, File.dirname(__FILE__))
end

if ENV['CI'] == 'true'
  require 'simplecov-cobertura'
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
else
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
end
