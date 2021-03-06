# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.2
# License: MIT

require 'csv'

# Whether or not to generate PDFs
generate_pdfs = true

# Regex to match the following alphabet: ^[a-km-zA-HJ-NPRT-Z2-46-9]{7,7}$
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
def token_arg_count_validator
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

# Writes tokens to PDFs
class PDFWriter
  # Compile a unique PDF for a singular organization with its passwords and
  #   moves it to the 'pdfs' directory
  #
  # @param [String] org The name of the organization
  # @param [String] org_tex The contents of the Latex to be written
  def self.write_latex_to_pdf(org, org_tex)
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
  def self.create_org_pdf(tex_file, org, org_passwords)
    org_tex = tex_file.clone

    org_tex = org_tex.gsub('REPLACESCHOOL', org)

    # Has to be triple escaped to account for the un-escaping done by ruby, then regex, then latex
    password_text = org_passwords.join(" \\\\\\\\\n")
    org_tex = org_tex.gsub('REPLACEPW', password_text)

    write_latex_to_pdf(org, org_tex)
    format("PDF generated for %<Org>s\n", Org: org)
  end

  # Create a unique PDF for each organization with its passwords
  #
  # @param [Hash<String => Array<String>>] all_tokens a mapping of organization
  #   names onto their associated passwords
  # @param [String] tex_file The file contents to print
  # @return [String] The console output for the generation
  def self.create_pdfs(all_tokens, tex_file)
    all_tokens.each do |org, org_passwords|
      puts create_org_pdf(tex_file, org, org_passwords)
    end

    system('mv *.pdf pdfs/')
    system('rm *.out *.aux *.log *.tex')
    format('%<TokenCount>d PDFs generated', TokenCount: all_tokens.length)
  end
end

# Creates a set of tokens
class TokenGenerator
  # Write all newly generated tokens to CSVs
  #
  # @param [Hash<String => Array<String>>] all_tokens a mapping of organization
  #   names onto their associated passwords
  # @param [String] file The file to write the tokens to
  def self.write_tokens_to_csv(all_tokens, file)
    CSV.open(file, 'w') do |f|
      f << %w[Organization Token]
      all_tokens.each do |org, org_passwords|
        org_passwords.each do |password|
          f << [org, password]
        end
      end
    end
  end

  # Read the contents of the given CSV file
  #
  # @param [String] file_name The name of the file
  # @return [Array<Array<String>>]the contents of the given CSV file
  def self.read_delegate_csv(file_name)
    begin
      # @type [Array<Array<String>>]
      csv = CSV.read(file_name)
    rescue Errno::ENOENT
      warn format('Sorry, the file %<File>s does not exist', File: file_name)
      exit 1
    end
    csv.delete_if { |line| line.join('') =~ /^\s*$/ } # delete blank lines
    csv
  end

  # @param [Integer] length The length of the string to be generated
  # @return [String] The randomized string
  # @private
  def self.random_string(length)
    length.times.map { CHARS.sample }.join('')
  end

  # @private
  # @param [Hash<String => Array<String>>] all_tokens The tokens already
  #   generated, used to prevent duplicates
  # @param [Numeric] token_length The length of the token
  # @return [String] the new token
  def self.gen_token(all_tokens, token_length = TOKEN_LENGTH)
    new_token = ''
    loop do
      new_token = random_string(token_length)
      break unless all_tokens.values.flatten.include?(new_token) ||
                   new_token =~ SWEAR_PREVENTION_MATCHER
    end
    new_token
  end

  # Processes the number of delegates given to a single chapter
  #
  # @param [CSV::Row|Enumerator] line The elements from this line to be processed
  # @param [Hash<Integer => integer>] column The columns containing pertinent info
  # @param [Hash<String => Array<String>>] all_tokens
  def self.process_chapter(line, column, all_tokens)
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

  # Determines what columns indices contain the organizations and delegate counts
  #
  # @param [Hash<Integer => integer>] columns The mapping to put the columns into
  # @param [Array<String>] line The header line
  def self.determine_header_columns(columns, line)
    # find the column with a header containing the keywords - non-case sensitive
    columns[:Org] = line.find_index do |token|
      token.match(/(schools?)|(organizations?)|(chapters?)|(names?)/i)
    end

    columns[:Delegates] = line.find_index do |token|
      token.match(/(delegates?)|(voter?s?)/i)
    end
  end

  # Parse the org and generate tokens
  #
  # @param [Hash<String => Array<String>>] all_tokens The mapping into which the tokens will be inserted
  # @param [Array<Array<String>>] lines The lines from the delegate count CSV
  def self.parse_organizations(all_tokens, lines)
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

  # Creates the token generation report string. Sets for which the count is nil or non-positive are not counted
  #
  # @param [Hash<String => Array<String>>] all_tokens The mapping into which the tokens were inserted
  # @return [String] A report of the number of tokens generated and the number of groups they are associated with
  def self.get_token_count_report(all_tokens)
    # noinspection RubyNilAnalysis
    trimmed_tokens = all_tokens.filter { |_, count| !count.nil? && count.length.positive? }
    format("%<TokenSetCount>d token sets generated (%<TokenCount>d total tokens)\n\n",
           TokenSetCount: trimmed_tokens.length,
           TokenCount: trimmed_tokens.map { |_, count| count.length }.reduce(:+))
  end

  # Manage the program
  #
  # @param [Boolean] generate_pdfs True if the program should generate PDFs with
  #   the generated passwords
  def self.main(generate_pdfs)
    # @type [Hash<String => Array<String>>]
    all_tokens = {}
    token_arg_count_validator
    lines = read_delegate_csv ARGV[0]

    parse_organizations(all_tokens, lines)
    write_tokens_to_csv(all_tokens, ARGV[1])

    puts get_token_count_report all_tokens
    puts PDFWriter.create_pdfs(all_tokens, IO.read('pdfs/template/voting.tex')) if generate_pdfs
  end
end

TokenGenerator.main generate_pdfs if __FILE__ == $PROGRAM_NAME
