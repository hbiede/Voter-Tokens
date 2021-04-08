# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.1
# License: MIT

require 'csv'

# Whether or not to generate PDFs
generate_pdfs = true

# noinspection SpellCheckingInspection
CHARS = 'qwertyuiopasdfghjkzxcvbnmWERTYUPADFGHJKLZXCVBNM2346789'.scan(/\w/)

# Apologies for the obscenities, but have to prevent these from showing up in
# the passwords
SWEAR_PREVENTION_MATCHER = /(fuc?k)|(fag)|(cunt)|(n[i1]g)|(a[s5][s5])|
([s5]h[i1]t)|(b[i1]a?t?ch)|(c[l1][i1]t)|(j[i1]zz)|([s5]ex)|([s5]meg)|
(d[i1]c?k?)|(pen[i1][s5])|(pube)|(p[i1][s5][s5])|(g[o0]d)|(crap)|(b[o0]ne)|
(basta)|(ar[s5])|(ana[l1])|(anu[s5])|(ba[l1][l1])|(b[l1][o0]w)|(b[o0][o0]b)|
([l1]mf?a[o0])/ix.freeze

# how many characters to pad
TOKEN_LENGTH = 7

# Determines if sufficient arguments were given to the program
#   else, exits
def arg_count_validator
  # print help if no arguments are given or help is requested
  return unless ARGV.length < 2 || ARGV[0] == '--help'

  error_message = 'Usage: ruby %s [VoterInputFileName] [TokenOutputFileName]'
  error_message += "\n\tOne header must contain \"School\", \"Organization\", "
  error_message += 'or "Chapter"'
  error_message += "\n\tAnother header must contain \"Delegates\" or \"Votes\""
  warn format(error_message, $PROGRAM_NAME)
  exit 1
end

# Prints a warning about the proper formatting of the CSV before exiting
def invalid_headers_warning
  warn 'Invalid CSV:'
  warn "\n\tHeaders should be \"School\" and \"Delegates\" in any order"
  exit 1
end

# Read the contents of the given CSV file
#
# @param [String] file_name The name of the file
# @return [Array<Array<String>>]the contents of the given CSV file
def read_csv(file_name)
  begin
    # @type [Array<Array<String>>]
    csv = CSV.read(file_name)
  rescue Errno::ENOENT
    warn format('Sorry, the file %<File>s does not exist', File: file_name)
    exit 1
  end
  csv.delete_if { |line| line =~ /^\s*$/ } # delete blank lines
  csv
end

# @param [Integer] length The length of the string to be generated
# @return [String] The randomized string
# @private
def random_string(length)
  length.times.map { CHARS.sample }.join('')
end

# @private
# @param [Hash<String => Array<String>>] all_tokens The tokens already
#   generated, used to prevent duplicates
def gen_token(all_tokens)
  new_token = ''
  loop do
    new_token = random_string(TOKEN_LENGTH)
    break unless all_tokens.value?(new_token) ||
                 new_token =~ SWEAR_PREVENTION_MATCHER
  end
  new_token
end

# Processes the number of delegates given to a single chapter
#
# @param [CSV::Row|Enumerator] line The elements from this line to be processed
# @param [Hash<Integer>] column The columns containing pertinent info
# @param [Hash<String => Array<String>>] all_tokens
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

# Initialize the program
#
# @return [Array<Array<String>>] the Delegate counts per organization
def init
  arg_count_validator

  read_csv(ARGV[0])
end

# Determines what columns indices contain the organizations and delegate counts
def determine_header_columns(columns, line)
  # find the column with a header containing the keywords - non-case sensitive
  columns[:Org] = line.find_index do |token|
    token.match(/(schools?)|(organizations?)|(chapters?)|(names?)/i)
  end

  columns[:Delegates] = line.find_index do |token|
    token.match(/(delegates?)|(voter?s?)/i)
  end
end

def parse_organizations(all_tokens, lines)
  # index of our two key columns (all other columns are ignored)
  # @type [Hash<Integer => integer>]
  columns = { Org: 0, Delegates: 0 }

  # tokenize all strings to a 2D array
  lines.each do |line|
    if columns[:Org].nil? || columns[:Delegates].nil?
      invalid_headers_warning
    elsif columns[:Org] == columns[:Delegates]
      # header line
      determine_header_columns(columns, line)
    else
      process_chapter(line, columns, all_tokens)
    end
  end
end

# Write all newly generated tokens to CSVs
#
# @param [Hash<String => Array<String>>] all_tokens a mapping of organization
#   names onto their associated passwords
def write_tokens_to_csv(all_tokens)
  CSV.open(ARGV[1], 'w') do |f|
    f << %w[Organization Token]
    all_tokens.each do |org, org_passwords|
      org_passwords.each do |password|
        f << [org, password]
        puts format('Token generated for %<Org>s\n', Org: org)
      end
    end
  end
end

# Compile a unique PDF for a singular organization with its passwords and
#   moves it to the 'pdfs' directory
#
# @param [String] org The name of the organization
# @param [String] org_tex The contents of the Latex to be written
def write_latex_to_pdf(org, org_tex)
  # noinspection RegExpRedundantEscape
  pdf_name = format('%<FileName>s.tex', FileName: org.gsub(/[\s().#!]/, ''))
  File.open(pdf_name, 'w') { |f| f.write(org_tex) }
  output = `lualatex #{pdf_name} 2>&1`
  result = $CHILD_STATUS.success?
  if result
    system(format('lualatex %<File>s > /dev/null', File: pdf_name))
  else
    warn output
    exit 1
  end
end

# Create a unique PDF for a singular organization with its passwords and
#   moves it to the 'pdfs' directory
#
# @param [String] tex_file The contents of the Latex template
# @param [String] org The name of the organization
# @param [Array<String>] org_passwords A collection of passwords for a given
#   organization
def create_org_pdf(tex_file, org, org_passwords)
  password_text = org_passwords.join('\\\\n')
  org_tex = tex_file.clone
  org_tex['REPLACESCHOOL'] = org
  org_tex['REPLACEPW'] = password_text
  write_latex_to_pdf(org, org_tex)
  puts format("PDF generated for %<Org>s\n", Org: org)
end

# Create a unique PDF for each organization with its passwords
#
# @param [Hash<String => Array<String>>] all_tokens a mapping of organization
#   names onto their associated passwords
def create_pdfs(all_tokens)
  tex_file = IO.read('pdfs/voting.tex')
  all_tokens.each do |org, org_passwords|
    create_org_pdf(tex_file, org, org_passwords)
  end

  system('mv *.pdf pdfs/')
  system('rm *.out *.aux *.log *.tex')
  puts format('%<TokenCount>d PDFs generated', TokenCount: all_tokens.length)
end

# Manage the program
#
# @param [Boolean] generate_pdfs True if the program should generate PDFs with
#   the generated passwords
def main(generate_pdfs)
  # @type [Hash<String => Array<String>>]
  all_tokens = {}
  lines = init

  parse_organizations(all_tokens, lines)
  write_tokens_to_csv(all_tokens)
  puts format("%<TokenSetCount>d token sets generated (%<TokenCount>d total tokens)\n\n",
              TokenSetCount: all_tokens.length,
              TokenCount: all_tokens.map { |y| y[1].length if y[1] }.reduce(:+))

  create_pdfs(all_tokens) if generate_pdfs
end

main generate_pdfs
