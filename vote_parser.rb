# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.2
# License: MIT

require 'csv'

# Read the contents of the given CSV file
#
# @param [String] file_name The name of the file
# @return [Array<Array<String>>]the contents of the given CSV file
def read_vote_csv(file_name)
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
  # @return [Array<Array<String>>]the contents of the token file
  def self.read_tokens(file)
    tokens = read_vote_csv file
    tokens.delete_at(0) # remove headers
    tokens
  end

  # Adds a new Hash to vote_counts if necessary
  #
  # @param [Hash{String => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @param [Integer] position The index of the vote position in vote
  def self.add_position_to_vote_counts(vote_counts, position)
    vote_counts.store(position, {}) unless vote_counts.include?(position)
  end

  # Parses out a single vote and applies its totals to the valid vote counts
  #
  # @param [Hash{String => Hash{String => Integer}}] vote_counts The mapping of a
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

  # Validate an entire ballot and parse out its component votes
  #
  # @param [Hash{String => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @param [Hash{String => Boolean}] used_tokens A collection of all the tokens already used
  # @param [Array<String>] vote A collection of the individuals receiving votes
  # @param [Hash{Symbol => String}] token_mapping The mapping of the token onto a school. Used for validating tokens
  # @return [String] the warning associated with the vote
  def self.validate_vote(vote_counts, used_tokens, vote, token_mapping)
    if used_tokens.include?(vote[0])
      format("%<ID>s (%<School>s) voted multiple times. Using latest.\n", ID: vote[0], School: token_mapping[vote[0]])
    else
      used_tokens.store(vote[0], true)
      # token hasn't been used. count votes
      (1...vote.length).each do |position|
        next if vote[position].nil? || vote[position].empty?

        parse_single_vote(vote_counts, vote, position)
      end
      ''
    end
  end

  # Count the number of votes in each position
  #
  # @param [Hash{String => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @param [Hash{String => Boolean}] used_tokens A collection of all the tokens already used
  # @param [Array[Array[String]]] votes The 2D array interpretation of the CSV
  # @param [Hash{Symbol => String}] token_mapping The mapping of the token onto a school
  # @return [String] the warnings generated
  def self.generate_vote_totals(vote_counts, used_tokens, votes, token_mapping)
    warning = ''
    votes.reverse.each do |vote|
      warning += if token_mapping.key?(vote[0])
                   validate_vote(vote_counts, used_tokens, vote, token_mapping)
                 else
                   format("%<VoteToken>s is an invalid token. Vote not counted.\n",
                          VoteToken: vote[0])
                 end
    end
    warning
  end

  # Get the necessary input processed
  #
  # @param [String] file The file to read votes from
  # @return [Hash{Symbol=>Array<Array<String>>,Hash{String}] A collection of the votes (Array of
  #   Strings), the token regex, and the column headers (Array of Strings)
  def self.init(vote_file, token_file)
    votes = read_vote_csv vote_file
    tokens = read_tokens token_file
    token_mapping = tokens.map { |token| [token[1], token[0]] }.to_h

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
  # @param [Hash{Symbol => String}] token_mapping The mapping of the token onto a school
  # @return [Hash{Symbol=>Integer,String,Hash{String}] A collection of the primary output and all warnings
  def self.process_votes(votes, token_mapping)
    # @type [Hash{String=> Hash{String=>Integer}}]
    vote_counts = {}

    # @type [Hash{String => Boolean}]
    used_tokens = {}

    warning = generate_vote_totals(vote_counts, used_tokens, votes, token_mapping)
    { TotalVoterCount: used_tokens.length, VoteCounts: vote_counts, Warning: warning }
  end
end

# Create a print out
class OutputPrinter
  # Write the output of the program to file if a file is given
  #
  # @param [String?] file The file to write to
  # @param [String] election_report The main body of the report
  # @param [String] warning All warnings printed in the output
  def self.write_election_report(file, election_report, warning = '')
    return if file.nil?

    File.write(file,
               format("%<Rule>s\n%<Time>s\n%<Rule>s\n%<Warn>s\n%<Report>s\n\n",
                      Rule: ('-' * 20), Time: Time.now.to_s, Warn: warning,
                      Report: election_report), mode: 'a')
    nil
  end

  # Generate a formatted string of a single ballot entry
  #
  # @param [String] candidate_name The name of the candidate
  # @param [Integer] votes The number of votes they received
  # @return [String] a formatted string of a single ballot entry
  def self.ballot_entry_string(candidate_name, votes, percent)
    majority_mark = if percent > 50
                      '*'
                    else
                      ' '
                    end
    format("\t%<MjrMarker>s%<Name>-20s %<Votes>4d vote%<S>s (%<Per>.2f%%)\n",
           Name: "#{candidate_name}:", Votes: votes,
           S: votes != 1 ? 's' : ' ', MjrMarker: majority_mark, Per: percent)
  end

  # Generate a formatted string of the number of abstention votes cast
  #
  # @param [Integer] vote_count The number of total votes cast (including
  #   abstentions)
  # @param [Integer] position_vote_count The number of votes cast for candidates
  # @return [String] the number of abstention votes cast
  def self.abstention_count_string(vote_count, position_vote_count)
    abstained = vote_count - position_vote_count
    if abstained.positive?
      format("\t %<Title>-20s %<AbsVotes>4d vote%<S>s\n",
             Title: 'Abstained:', AbsVotes: abstained,
             S: abstained != 1 ? 's' : '')
    else
      ''
    end
  end

  # Generate the abstention counts, underline, position totals as a string
  #
  # @param [Integer] vote_count The number of total votes cast in the election
  # @param [Integer] pos_total The number of votes cast in the election for
  #   positions (does not count abstentions)
  # @return [String] the abstention counts, underline, position totals as a string
  def self.position_report_totals(vote_count, pos_total)
    abstention_count_string(vote_count, pos_total) + '-' * 49 +
      format("\n\t %<Title>-20s %<TotalVotes>4d vote%<S>s\n\n",
             Title: 'Total:', TotalVotes: vote_count,
             S: vote_count != 1 ? 's' : '')
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
    return_string = ''
    # sort the positions by votes received in descending order
    position_vote_record.sort_by { |candidate, votes| [-votes, candidate] }.to_h.each_pair do |candidate, votes|
      return_string += ballot_entry_string(candidate.to_s, votes,
                                           100.0 * votes / vote_count)
    end
    return_string + position_report_totals(vote_count, pos_total)
  end

  # Sum the number of votes cast for a position (does not include abstentions)
  #
  # @param [Hash{String => Integer}] position_vote_record A mapping of candidate
  #   names onto the number of votes they received
  # @return [Integer] the number of votes cast for a position (does not include
  #   abstentions)
  def self.sum_position_votes(position_vote_record)
    pos_total = 0
    position_vote_record.each_pair { |_candidate, votes| pos_total += votes }
    pos_total
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
    format("\n%<Pos>s%<Maj>s\n%<Individuals>s",
           Pos: position_title, Maj: majority_reached_str, Individuals: individual_report)
  end

  # Generate a the overall vote report
  #
  # @param [Integer] vote_count The number of valid votes cast
  # @param [Array[String]] column_headers A listing of the column headers from the
  #   CSV (with 0 being the token)
  # @param [Hash{String => Hash{String => Integer}}] vote_counts The mapping of a
  #   position to a set of votes
  # @return [String] the vote report
  def self.vote_report(vote_count, column_headers, vote_counts)
    return_string = ''
    vote_counts.each_pair do |key, position_vote_record|
      return_string += position_report(vote_count, column_headers[key],
                                       position_vote_record)
    end
    return_string
  end

  # Write the output to the console, and optionally to a file
  #
  # @param [String] election_report The vote report
  # @param [String?] warning Potential warnings
  # @param [String?] file The optional file to which to write the output
  def self.write_output(election_report, warning, file)
    warn warning unless warning.nil? || warning.empty?
    puts election_report
    OutputPrinter.write_election_report(file, election_report, warning)
  end
end

# :nocov:
# Manage the program
def main
  VoteParser.vote_arg_count_validator ARGV
  input = VoteParser.init(ARGV[0], ARGV[1])
  # noinspection RubyMismatchedParameterType
  # @type [Hash{Symbol=>Integer,String,Hash{String}]
  processed_values = VoteParser.process_votes(input[:Votes], input[:TokenMapping])
  # noinspection RubyMismatchedParameterType
  election_report = OutputPrinter.vote_report(
    processed_values[:TotalVoterCount],
    input[:Cols],
    processed_values[:VoteCounts]
  )
  OutputPrinter.write_output(election_report, processed_values[:Warning], ARGV[2])
end

main if __FILE__ == $PROGRAM_NAME
# :nocov:
