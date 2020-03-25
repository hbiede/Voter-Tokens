# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.0
# License: MIT

require 'csv'

# noinspection SpellCheckingInspection
CHARS = 'qwertyuiopasdfghjkzxcvbnmWERTYUPASDFGHJKLZXCVBNM23456789'.scan(/\w/)

# how many characters to pad
TOKEN_LENGTH = 7

# @param [Integer] length The length of the string to be generated
# @return [String] The randomized string
# @private
def random_string(length)
  length.times.map { CHARS.sample }.join('')
end

# @private
# @param [Array<Hash<Integer, String>>] all_tokens The tokens already generated,
# used to prevent duplicates
def gen_token(all_tokens)
  new_token = ''
  loop do
    new_token = random_string(TOKEN_LENGTH)
    break unless all_tokens.any? { |_, token| token.equal?(new_token) }
  end
  new_token
end

# @param [CSV::Row|Enumerator] line The elements from this line to be processed
# @param [Hash<Integer>] column The columns containing pertinent info
# @param [Array<Hash<Integer, String>>] all_tokens
def process_chapter(line, column, all_tokens)
  org = line[column[:Org]]
  (0...line[column[:Delegates]].to_i).each do
    # gen tokens and push to the csv
    all_tokens.push({ 0 => org, 1 => gen_token(all_tokens) })
  end
end

# print help if no arguments are given or help is requested
if ARGV.length < 2 || ARGV[0] == '--help'
  error_message = 'Usage: ruby %s [VoterInputFileName] [TokenOutputFileName]'
  error_message += "\n\tOne header must contain \"School\", \"Organization\", "
  error_message += 'or "Chapter"'
  error_message += "\n\tAnother header must contain \"Delegates\" or \"Votes\""
  warn format(error_message, $PROGRAM_NAME)
  exit 1
end

# read from the passed file and catch possible IO error
begin
  lines = CSV.read(ARGV[0])
rescue Errno::ENOENT
  warn 'Sorry, that file does not exist'
  exit 1
end
lines.delete_if { |line| line =~ /^\s*$/ } # delete blank lines

# @type [Array<Hash<Integer, String>>]
all_tokens = []
# index of our two key columns (all other columns are ignored)
# @type [Hash<Integer>]
column = { Org: 0, Delegates: 0 }

# tokenize all strings to a 2D array
lines.each do |line|
  if column[:Org].nil? || column[:Delegates].nil?
    warn 'Invalid CSV:'
    warn "\n\tHeaders should be \"School\" and \"Delegates\" in any order"
    exit 1
  elsif column[:Org] == column[:Delegates]
    # header line

    # find the column with a header containing the keywords - non-case sensitive
    column[:Org] = line.find_index do |token|
      token.match(/(school)|(organization)|(chapter)/i)
    end

    column[:Delegates] = line.find_index do |token|
      token.match(/(delegates?)|(voter?s?)/i)
    end
  else
    process_chapter(line, column, all_tokens)
  end
end

CSV.open(ARGV[1], 'w') do |f|
  f << %w[Organization Token]
  all_tokens.each do |line|
    f << [line[0], line[1]]
  end
end
