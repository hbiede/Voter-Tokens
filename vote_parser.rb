# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.6
# License: MIT

require 'csv'
require 'json'
require 'optparse'
require 'singleton'

# Parses CLI flags
class OptionHandler
  include Singleton

  def initialize
    @options = { reverse: false, json: false }
    parse_options
  end

  def json?
    @options[:json]
  end

  def reversed?
    @options[:reverse]
  end

  private

  def parse_options
    OptionParser.new do |opt|
      opt.on(
        '-o',
        '--in-order',
        TrueClass,
        'If the votes should be counted in chronological order, keeping the first (defaults to false)'
      ) { |o| @options[:reverse] = o }
      opt.on(
        '--json',
        TrueClass,
        'If the votes should be output as JSON (defaults to false)'
      ) { |o| @options[:json] = o }
    end.parse!
  end
end

# Strip timestamps from vote results
#
# @param [Array<Array<String>>] csv the contents of the given CSV to remove the timestamps from
# @return [Array<Array<String>>] the file with timestamps removed
def remove_timestamps(csv)
  return [] if csv.nil? || csv.empty?

  timestamp_index = csv[0].index { |col| col =~ /Timestamp/i }

  if timestamp_index.nil?
    csv
  else
    csv.map do |row|
      row.delete_at timestamp_index
      row
    end
  end
end

# Read the contents of the given CSV file
#
# @param [String] file_name The name of the file
# @return [Array<Array<String>>] the contents of the given CSV file
def read_vote_csv(file_name)
  begin
    # @type [Array<Array<String>>]
    csv = CSV.read(file_name)
  rescue Errno::ENOENT
    warn format('Sorry, the file %<File>s does not exist', File: file_name)
    exit 1
  end
  csv.delete_if { |line| line.join =~ /^\s*$/ } # delete blank lines
  remove_timestamps csv
end

# Parse a vote record
class VoteParser
  # Determines if sufficient arguments were given to the program
  #   else, exits
  # @param [Array<string>] args The arguments to the program
  def self.vote_arg_count_validator(args)
    # print help if no arguments are given or help is requested
    return unless args.length < 2 || args.include?('--help')

    error_message = 'Usage: ruby %s [VoteInputFileName] [TokenInputFileName]'
    error_message += "\n\tColumn one of votes must be the token (password)"
    error_message += "\n\tAn optional path to an output file may also be given"
    error_message += ' to output the report to a text file'
    warn format(error_message, $PROGRAM_NAME)

    raise ArgumentError unless args.include?('--help')

    exit 0
  end

  # Read the contents of the token file
  #
  # @param [String] file The file to read from
  # @return [Array<Array<String>>] the contents of the token file
  def self.read_tokens(file)
    tokens = read_vote_csv file
    tokens.delete_at(0) # remove headers
    tokens
  end

  # Adds a new Hash to vote_counts if necessary
  #
  # @param [Hash{Integer => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @param [Integer] position The index of the vote position in vote
  def self.add_position_to_vote_counts(vote_counts, position)
    vote_counts.store(position, {}) unless vote_counts.include?(position)
  end

  # Parses out a single vote and applies its totals to the valid vote counts
  #
  # @param [Hash{Integer => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @param [Array<String>] vote A collection of the individuals receiving votes
  # @param [Integer] position The index of the vote position in vote
  def self.parse_single_vote(vote_counts, vote, position)
    add_position_to_vote_counts(vote_counts, position)

    if vote_counts[position].include?(vote[position])
      vote_counts[position][vote[position]] += 1
    else
      vote_counts[position].store(vote[position], 1)
    end
  end

  # @param [String] token The multi-voting token
  # @param [String] school The school the token is from
  # @return [String] the warning associated with the vote
  def self.get_double_vote_string(token, school)
    order_string = OptionHandler.instance.reversed? ? 'latest' : 'first'

    "#{token} (#{school}) voted multiple times. Using #{order_string}."
  end

  # Validate an entire ballot and parse out its component votes
  #
  # @param [Hash{Integer => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @param [Hash{String => Boolean}] used_tokens A collection of all the tokens already used
  # @param [Array<String>] vote A collection of the individuals receiving votes
  # @param [Hash{String => String}] token_mapping The mapping of the token onto a school. Used for validating tokens
  # @return [String] the warning associated with the vote
  def self.validate_vote(vote_counts, used_tokens, vote, token_mapping)
    if used_tokens.include?(vote[0])
      get_double_vote_string(vote[0], token_mapping[vote[0]])
    else # token hasn't been used. count votes
      used_tokens.store(vote[0], true)
      (1...vote.length).each do |position|
        next if vote[position].nil? || vote[position].empty?

        parse_single_vote(vote_counts, vote, position)
      end
      ''
    end
  end

  # Count the number of votes in each position
  #
  # @param [Hash{Integer => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @param [Hash{String => Boolean}] used_tokens A collection of all the tokens already used
  # @param [Array[Array[String]]] votes The 2D array interpretation of the CSV
  # @param [Hash{String => String}] token_mapping The mapping of the token onto a school
  # @return [Array[String]] the warnings generated
  def self.generate_vote_totals(vote_counts, used_tokens, votes, token_mapping)
    (OptionHandler.instance.reversed? ? votes.reverse : votes).map do |vote|
      if token_mapping.key?(vote[0])
        validate_vote(vote_counts, used_tokens, vote, token_mapping)
      else
        "#{vote[0]} is an invalid token. Vote not counted."
      end
    end.reject(&:empty?)
  end

  # Get the necessary input processed
  #
  # @param [String] file The file to read votes from
  # @return [Hash{Symbol=>Array<Array<String>>,Hash{String}] A collection of the votes (Array of
  #   Strings), the token regex, and the column headers (Array of Strings)
  def self.init(vote_file, token_file)
    votes = read_vote_csv vote_file
    tokens = read_tokens token_file
    token_mapping = tokens.to_h { |token| [token[1], token[0]] }

    # get the column headers and remove them from the voting pool
    # @type [Hash{Integer => String}]
    column_headers = votes.first.nil? ? [] : votes.first
    votes.delete_at(0)
    { Votes: votes, TokenMapping: token_mapping, Cols: column_headers }
  end

  # Process the input and count all votes
  #
  # @param [Array<Array<String>>] votes The collection of votes as a 2D array with
  #   rows representing individual ballots and columns representing entries votes
  #   for a given position
  # @param [Hash{String => String}] token_mapping The mapping of the token onto a school
  # @return [Hash{Symbol=>Integer,String,Hash{Integer=>Hash{String=>Integer}}] A
  #   collection of the primary output and all warnings
  def self.process_votes(votes, token_mapping)
    # @type [Hash{Integer=>Hash{String=>Integer}}]
    vote_counts = {}

    # @type [Hash{String => Boolean}]
    used_tokens = {}

    warning = generate_vote_totals(vote_counts, used_tokens, votes, token_mapping)
    { TotalVoterCount: used_tokens.length, VoteCounts: vote_counts, Warning: warning }
  end
end

# Convert arrays of text into a formatted text table
class TableGenerator
  # Format an array of strings into a table
  #
  # @param [Array<Array<String>>] body the main content of the table
  # @param [Array<String>] header an optional header to prepend to the table
  # @param [Array<String>] footer an optional footer to append to the table
  # @return [String] a table formatted as a string
  def self.generate(body, header: [], footer: [])
    lengths = get_table_lengths(body, header, footer)

    result = generate_header(header, lengths)
    result += "#{generate_body(body, lengths)}\n"
    result += generate_footer(footer, lengths)
    result.strip
  end

  # @param [Array<Array<String>>] body the main body of the table
  # @param [Array<String>] header the header of the table
  # @param [Array<String>] footer the footer of the table
  # @return [Integer] the number of columns
  def self.get_column_count(body, header, footer)
    body_columns = body.map(&:length).max
    [body_columns.nil? ? 0 : body_columns, header.length, footer.length].max.to_i
  end

  def self.get_body_lengths(body, column_count)
    lengths = Array.new(column_count, 0)
    body.each do |row|
      row.each_with_index do |entry, i|
        lengths[i] = [entry.length, lengths[i]].max
      end
    end
    lengths
  end

  # @param [Array<Array<String>>] body the main body of the table
  # @param [Array<String>] header the header of the table
  # @param [Array<String>] footer the footer of the table
  # @return [Array<Integer>] the length of each column
  def self.get_table_lengths(body, header, footer)
    column_count = get_column_count(body, header, footer)
    return [] if column_count.zero?

    lengths = get_body_lengths(body, column_count)
    header.each_with_index { |entry, i| lengths[i] = [entry.length, lengths[i]].max }
    footer.each_with_index { |entry, i| lengths[i] = [entry.length, lengths[i]].max }
    lengths
  end

  # Generate a horizontal divider line
  #
  # @param [Array<Integer>] lengths the length of each column of the table
  # @return [String] the resulting divider line that aligns to the given column lengths
  def self.generate_break_line(lengths, with: '-')
    return '' if lengths.empty? || lengths.all?(&:zero?)

    "+#{with}#{lengths.map { |length| with * length }.join "#{with}+#{with}"}#{with}+\n"
  end

  # @param [Array<String>] array the array of strings to pad
  # @param [Array<Integer>] with the desired length of each entry
  # @return [Array<String>] the padded array
  def self.pad(array, with:, left_align: false)
    formatted_array = array.each_with_index.map { |entry, i| format("%#{left_align ? '-' : ''}#{with[i]}s", entry) }
    if formatted_array.length < with.length
      formatted_array.concat(with[formatted_array.length..with.length].map { |length| ' ' * length })
    end
    formatted_array
  end

  # Generate the header text for a table
  #
  # @param [Array<String>] header the header text to generate
  # @param [Array<Integer>] lengths the length of each column of the table
  # @return [String] the resulting header string
  def self.generate_header(header, lengths)
    if header.empty? || header.all?(&:empty?)
      generate_break_line(lengths)
    else
      "#{generate_break_line(lengths)}| #{pad(header,
                                              with: lengths,
                                              left_align: true).join(' | ')} |\n#{generate_break_line(lengths,
                                                                                                      with: '=')}"
    end
  end

  # Generate the body text of the table
  #
  # @param [Array<Array<String>>] body the main content of the table
  # @param [Array<Integer>] lengths the length of each column in the table
  # @return [String] the resulting body string
  def self.generate_body(body, lengths)
    body
      .filter { |row| row.any? { |entry| !entry.empty? } }
      .map { |row| "| #{pad(row, with: lengths).join(' | ')} |" }.join "\n"
  end

  # Generate the footer text for a table
  #
  # @param [Array<String>] footer the header text to generate
  # @param [Array<Integer>] lengths the length of each column of the table
  # @return [String] the resulting footer string
  def self.generate_footer(footer, lengths)
    if footer.empty? || footer.all?(&:empty?)
      generate_break_line(lengths)
    else
      "#{generate_break_line(lengths,
                             with: '=')}| #{pad(footer,
                                                with: lengths).join(' | ')} |\n#{generate_break_line(lengths)}"
    end
  end
end

# Create and handle output
class OutputPrinter
  MESS = 'SYSTEM ERROR: method missing'

  def vote_report
    raise MESS
  end

  # Write the output of the program to file if a file is given
  #
  # @param [String] election_report The main body of the report
  # @param [String?] to The file to write to
  def self.write_election_report(election_report, to:)
    return if to.nil?

    File.write(to, election_report, mode: 'a')
    nil
  end

  # Write the output to the console, and optionally to a file
  #
  # @param [String] election_report The vote report
  # @param [String?] warning Potential warnings
  # @param [String?] file The optional file to which to write the output
  def self.write_output(election_report, warning, file)
    warn warning unless warning.nil? || warning.empty?
    puts election_report
    OutputPrinter.write_election_report(election_report, to: file)
  end
end

# Create a human-readable print-out
class ReadableOutputPrinter < OutputPrinter
  # Generate values representing the vote counts for a given candidate
  #
  # @param [String] candidate_name The name of the candidate
  # @param [Integer] votes The number of votes they received
  # @return [Array<String>] a formatted string of a single ballot entry
  def self.ballot_entry_values(candidate_name, votes, percent)
    majority_mark = percent > 50 ? '*' : ''
    ["#{majority_mark}#{candidate_name}",
     "#{votes} vote#{votes == 1 ? ' ' : 's'}",
     format('%<Per>.2f%%', Per: percent)]
  end

  # Generate values representing the abstain votes for a given position
  #
  # @param [Integer] vote_count The number of total votes cast (including
  #   abstentions)
  # @param [Integer] position_vote_count The number of votes cast for candidates
  # @return [Array<String>] the number of abstention votes cast
  def self.abstention_count_values(vote_count, position_vote_count)
    abstained = vote_count - position_vote_count
    if abstained.positive?
      ['[Abstained]', "#{abstained} vote#{abstained == 1 ? ' ' : 's'}"]
    else
      []
    end
  end

  # Generate the entire report for a given position
  #
  # @param [Integer] vote_count The number of total votes cast in the election
  # @param [Integer] pos_total The number of votes cast in the election for
  #   positions (does not count abstentions)
  # @param [Hash{String => Integer}] position_vote_record A mapping of candidate
  #   names onto the number of votes they received
  # @return [String] the entire report for a given position
  def self.position_report_individuals(vote_count, pos_total, position_vote_record)
    # sort the positions by votes received in descending order
    result_entries = position_vote_record
                     .sort_by { |candidate, votes| [-votes, candidate] }
                     .to_h
                     .map do |candidate, votes|
      ballot_entry_values(candidate.to_s, votes, 100.0 * votes / vote_count)
    end
    abstentions = abstention_count_values(vote_count, pos_total)
    result_entries.push abstentions unless abstentions.empty?
    footer = ['Total', "#{vote_count} vote#{vote_count == 1 ? ' ' : 's'}"]
    TableGenerator.generate(result_entries, footer: footer)
  end

  # Sum the number of votes cast for a position (does not include abstentions)
  #
  # @param [Hash{String => Integer}] position_vote_record A mapping of candidate
  #   names onto the number of votes they received
  # @return [Integer] the number of votes cast for a position (does not include
  #   abstentions)
  def self.sum_position_votes(position_vote_record)
    position_vote_record.values.sum
  end

  # Determine if a majority has been reached
  #
  # @param [Integer] vote_count The number of total votes cast in the election
  # @param [Hash{String => Integer}] position_vote_record A mapping of candidate
  #   names onto the number of votes they received
  # @return [Boolean] true iff a majority was reached
  def self.majority_reached?(vote_count, position_vote_record)
    return false if vote_count.zero?

    majority_reached = false
    position_vote_record.each_pair do |_candidate, votes|
      majority_reached |= 100.0 * votes / vote_count > 50
    end
    majority_reached
  end

  # Generate the vote report for a single position
  #
  # @param [Integer] vote_count The number of total votes cast in the election
  # @param [String] position_title The name of the position being sought after
  # @param [Hash{String => Integer}] position_vote_record A mapping of candidate
  #   names onto the number of votes they received
  # @return [String] the vote report for a single position
  def self.position_report(vote_count, position_title, position_vote_record)
    pos_total = sum_position_votes(position_vote_record)
    individual_report = position_report_individuals(vote_count, pos_total,
                                                    position_vote_record)
    majority_reached_str = if majority_reached?(vote_count, position_vote_record)
                             ''
                           else
                             ' (No Majority)'
                           end
    format("\n\n%<Pos>s%<Maj>s\n%<Individuals>s", Pos: position_title, Maj: majority_reached_str,
                                                  Individuals: individual_report)
  end

  # Generate the overall vote report
  #
  # @param [Integer] vote_count The number of valid votes cast
  # @param [Array[String]] column_headers A listing of the column headers from the
  #   CSV (with 0 being the token)
  # @param [Hash{Integer => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @param [Array[String]] warnings The list of warnings
  # @return [String] the vote report
  def self.vote_report(vote_count, column_headers, vote_counts, warnings)
    format("%<Rule>s\n%<Time>s\n%<Rule>s\n%<Warn>s%<Report>s\n\n",
           Rule: ('-' * 20),
           Time: Time.now.to_s,
           Warn: warnings.empty? ? '' : "#{warnings.join("\n")}\n",
           Report: vote_counts.map do |key, position_vote_record|
             position_report(vote_count, column_headers[key], position_vote_record)
           end.join)
  end
end

# Convert a vote report to a JSON output
class JSONOutputPrinter < OutputPrinter
  # Generate the overall vote report
  #
  # @param [Integer] vote_count The number of valid votes cast
  # @param [Array[String]] column_headers A listing of the column headers from the
  #   CSV (with 0 being the token)
  # @param [Hash{Integer => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @param [Array[String]] warnings The list of warnings
  # @return [String] the vote report
  def self.vote_report(vote_count, column_headers, vote_counts, warnings)
    output_obj = { count: vote_count, positions: vote_counts.transform_keys { |key| column_headers[key] } }
    output_obj[:warnings] = warnings unless warnings.empty?
    JSON.pretty_generate(output_obj)
  end
end

def parse_input
  filtered_args = ARGV.reject { |arg| arg.nil? or arg.start_with?('-') }
  VoteParser.vote_arg_count_validator filtered_args

  VoteParser.init(filtered_args[0], filtered_args[1])
end

def output_printer
  OptionHandler.instance.json? ? JSONOutputPrinter : ReadableOutputPrinter
end

# :nocov:
# Manage the program
def main
  input = parse_input

  # noinspection RubyMismatchedParameterType,RubyMismatchedArgumentType
  # @type [Hash{Symbol=>Union{Integer,String,Hash{Integer=>Hash{String=>Integer}}}}]
  processed_values = VoteParser.process_votes(input[:Votes], input[:TokenMapping])

  printer = output_printer
  # noinspection RubyMismatchedParameterType,RubyMismatchedArgumentType
  election_report = printer.vote_report(
    processed_values[:TotalVoterCount],
    input[:Cols],
    processed_values[:VoteCounts],
    processed_values[:Warning]
  )
  printer.write_output(election_report, processed_values[:Warning], ARGV[2])
end

main if __FILE__ == $PROGRAM_NAME
# :nocov:
