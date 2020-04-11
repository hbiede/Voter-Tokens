# frozen_string_literal: true

# Author: Hundter Biede (hbiede.com)
# Version: 1.0
# License: MIT

require 'csv'

# Generate a formatted string of a single ballot entry
#
# @param [String] candidate_name The name of the candidate
# @param [Integer] votes The number of votes they received
# @return [String] a formatted string of a single ballot entry
def ballot_entry_string(candidate_name, votes, percent)
  if percent > 50
    majority_mark = '*'
  else
    majority_mark = ''
  end
  format("\t%<MajoriyMarker>1s%<Name>-20s %<Votes>4d vote%<S>s (%<Per>.2f%%)\n",
         Name: candidate_name + ':', Votes: votes,
         S: votes != 1 ? 's' : '', MajoriyMarker: majority_mark, Per: percent)
end

# Generate a formatted string of the number of abstention votes cast
#
# @param [Integer] vote_count The number of total votes cast (including
#   abstentions)
# @param [Integer] position_vote_count The number of votes cast for candidates
# @return [String] the number of abstention votes cast
def abstention_count_string(vote_count, position_vote_count)
  abstained = vote_count - position_vote_count
  if abstained.positive?
    return_string = format("\t%<Title>-20s %<AbsVotes>4d vote%<S>s\n",
                           Title: 'Abstained:', AbsVotes: abstained,
                           S: abstained != 1 ? 's' : '')
  else
    return_string = ''
  end
  return_string
end

# Generate the vote report for a single position
#
# @param [Integer] vote_count The number of total votes cast in the election
# @param [String] position_title The name of the position being sought after
# @param [Hash<String, Integer>] position_vote_record A mapping of candidate
#   names onto the number of votes they received
# @return [String] the vote report for a single position
def position_report(vote_count, position_title, position_vote_record)
  return_string = ''
  pos_total = 0
  majority_reached = false
  position_vote_record.each_pair { |candidate, votes| pos_total += votes }

  # sort the positions by votes received in decending order
  position_vote_record.sort_by { |candidate, votes| -votes }.to_h.each_pair do |candidate, votes|
    percent = 100.0 * votes / vote_count
    majority_reached |= percent > 50
    return_string += ballot_entry_string(candidate.to_s, votes, percent)
  end
  return_string += abstention_count_string(vote_count, pos_total) + '-' * 49
  return_string += format("\n\t %<Title>-20s %<TotalVotes>4d vote%<S>s\n\n",
                          Title: 'Total:', TotalVotes: vote_count,
                          S: pos_total != 1 ? 's' : '')
  majority_reached_string = ' (No Majority Reached)'
  if majority_reached
    majority_reached_string = ''
  end
  format("%<PositionTitle>s%<MajorityReached>s\n", PositionTitle: position_title,
         MajorityReached: majority_reached_string) + return_string
end

# Generate a the overall vote report
#
# @param [Integer] vote_count The number of valid votes cast
# @param [Array[String]] column_headers A listing of the column headers from the
#   CSV (with 0 being the token)
# @param [Hash<String, Hash<String,Integer>>] vote_counts The mapping of a
#   position to a set of votes
# @return [String] the vote report
def vote_report(vote_count, column_headers, vote_counts)
  return_string = ''
  vote_counts.each_pair do |key, position_vote_record|
    return_string += position_report(vote_count, column_headers[key],
                                     position_vote_record)
  end
  return_string
end

# Count the number of votes in each position
#
# @param [Array[Array[String]]] votes The 2D array interpretation of the CSV
# @param [Regexp] token_regex a regex expression to determine the validity of
#   a given token
# @return [Hash] the vote counts for each position
def generate_vote_totals(votes, token_regex)
  vote_counts = {}
  used_tokens = []
  warning = ''
  votes.reverse.each do |vote|
    if vote[0] =~ token_regex
      if used_tokens.include?(vote[0])
        warning += format("%<VoterID>s voted multiple times. Using latest.\n",
                          VoterID: vote[0])
      else
        used_tokens.push(vote[0])
        # token hasn't been used. count votes
        (1..vote.length - 1).each do |position|
          next if vote[position].nil? || vote[position].empty?

          vote_counts.store(position, {}) unless vote_counts.include?(position)

          if vote_counts[position].include?(vote[position])
            vote_counts[position][vote[position]] += 1
          else
            vote_counts[position].store(vote[position], 1)
          end
        end
      end
    else
      warning += format("%<VoteToken>s is an invalid token. Vote not Counted\n",
                        VoteToken: vote[0])
    end
  end
  warn warning
  { :VoteCounts => vote_counts, :VoteTotal => used_tokens.length }
end

# print help if no arguments are given or help is requested
if ARGV.length < 2 || ARGV[0] == '--help'
  error_message = 'Usage: ruby %s [VoteInputFileName] [TokenInputFileName]'
  error_message += "\n\tColumn one of votes must be the token (password)"
  error_message += "\n\tAn optional path to an output file may also be given"
  error_message += ' to output the report to a text file'
  warn format(error_message, $PROGRAM_NAME)
  exit 1
end

# read from the passed votes file and catch possible IO error
begin
  # @type [Array<Array<String>>]
  votes = CSV.read(ARGV[0])
rescue Errno::ENOENT
  warn 'Sorry, the votes file does not exist'
  exit 1
end
votes.delete_if { |line| line =~ /^\s*$/ } # delete blank lines

begin
  tokens = CSV.read(ARGV[1])
rescue Errno::ENOENT
  warn 'Sorry, the tokens file does not exist'
  exit 1
end
tokens.delete_if { |line| line =~ /^\s*$/ } # delete blank lines
tokens.delete_at(0) # remove headers

# @type [Regexp]
token_regex = /#{tokens.map { |token| Regexp.escape(token[1]) }.join("|")}/

# get the column headers and remove them from the voting pool
# @type [Hash<Integer, String>]
column_headers = votes.first
votes.delete_at(0)

vote_report = generate_vote_totals(votes, token_regex)
election_report = vote_report(vote_report[:VoteTotal], column_headers, vote_report[:VoteCounts])

unless ARGV[2].nil?
  File.write(ARGV[2], ('-' * 20) + "\n" + Time.now.to_s + "\n" +
      ('-' * 20) + "\n" + warning + "\n" + election_report + "\n\n\n",
             mode: 'a')
end
puts election_report
