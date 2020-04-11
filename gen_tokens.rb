# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.0
# License: MIT

require 'csv'

# Whether or not to generate PDFs
generate_pdfs = true

# noinspection SpellCheckingInspection
CHARS = 'qwertyuiopasdfghjkzxcvbnmWERTYUPASDFGHJKLZXCVBNM23456789'.scan(/\w/)

# Appologies for the obscenities, but have to prevent these from showing up in
# the passwords
SWEAR_PREVENTION_MATCHER = /(fuc?k)|(fag)|(cunt)|(n[i1]g)|(a[s5][s5])|
                            ([s5]h[i1]t)|(b[i1]a?t?ch)|(c[l1][i1]t)|
                            (j[i1]zz)|([s5]ex)|([s5]meg)|(d[i1]c?k?)|
                            (pen[i1][s5])|(pube)|(p[i1][s5][s5])|
                            (g[o0]d)|(crap)|(b[o0]ne)|(basta)|(ar[s5])|
                            (ana[l1])|(anu[s5])|(ba[l1][l1])|
                            (b[l1][o0]w)|(b[o0][o0]b)|([l1]mf?a[o0])/ix

# how many characters to pad
TOKEN_LENGTH = 7

# @param [Integer] length The length of the string to be generated
# @return [String] The randomized string
# @private
def random_string(length)
  length.times.map { CHARS.sample }.join('')
end

# @private
# @param [Hash<String, Array<String>>] all_tokens The tokens already generated,
# used to prevent duplicates
def gen_token(all_tokens)
  new_token = ''
  loop do
    new_token = random_string(TOKEN_LENGTH)
    break unless all_tokens.value?(new_token) ||
        new_token =~ SWEAR_PREVENTION_MATCHER
  end
  new_token
end

# @param [CSV::Row|Enumerator] line The elements from this line to be processed
# @param [Hash<Integer>] column The columns containing pertinent info
# @param [Hash<String, Array<String>>] all_tokens
def process_chapter(line, column, all_tokens)
  org = line[column[:Org]]
  (0...line[column[:Delegates]].to_i).each do
    # gen tokens and push to the csv
    if all_tokens.include?(org)
      all_tokens.fetch(org).push(gen_token(all_tokens))
    else
      all_tokens.store(org, [gen_token(all_tokens)])
    end
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

# @type [Hash<String, Array<String>>]
all_tokens = {}
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
      token.match(/(schools?)|(organizations?)|(chapters?)|(names?)/i)
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
  all_tokens.each do |org, org_passwords|
    org_passwords.each do |password|
      f << [org, password]
      puts 'Token generated for ' + org + "\n"
    end
  end
end
puts format("%<TokenCount>d tokens generated", TokenCount: all_tokens.length)

if generate_pdfs
  tex_file = IO.read('pdfs/voting.tex')
  all_tokens.each do |org, org_passwords|
    password_text = ''
    org_passwords.each do |password|
      password_text += password + " \\\\\n"
    end
    org_tex = tex_file.clone
    org_tex['REPLACESCHOOL'] = org
    org_tex['REPLACEPW'] = password_text
    pdf_name = org.gsub(/[\s\(\)\.#!]/, '') + '.tex'
    File.open(pdf_name, 'w') { |f| f.write(org_tex) }
    system('lualatex ' + pdf_name + ' > /dev/null')
    system('lualatex ' + pdf_name + ' > /dev/null')
    puts format("PDF generated for %<Org>s\n", Org: org)
  end

  system('rm *.out *.aux *.log *.tex')
  system('mv *.pdf pdfs/')
  puts format("%<TokenCount>d PDFs generated", TokenCount: all_tokens.length)
end
