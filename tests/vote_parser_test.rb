# Author: Hundter Biede (hbiede.com)
# Version: 1.2
# License: MIT
require_relative '../vote_parser'
require_relative './helper'

#noinspection RubyResolve
class TestVoteParser < Test::Unit::TestCase
  def test_read_tokens
    file = 'test_read_tokens.csv'
    CSV.open(file, 'w') do |f|
      f << %w[Organization Token]
      f << %w[A abc]
      f << %w[B 123]
    end

    assert_equal([
                     %w[A abc],
                     %w[B 123]
                 ], VoteParser.read_tokens(file))

    File.delete file

    begin
      VoteParser.read_tokens('fake_csv.csv')
    rescue SystemExit
      assert_true true
    else
      assert_true false
    end
  end

  # Maps onto add_position_to_vote_counts
  def test_add_position_to_counts
    votes = {}
    (1..10).each do
      VoteParser.add_position_to_vote_counts(votes, 0)
      assert_equal({ 0 => {} }, votes)
    end
    (1..10).each do
      VoteParser.add_position_to_vote_counts(votes, 1)
      assert_equal({ 0 => {}, 1 => {} }, votes)
    end
    (1..10).each do
      VoteParser.add_position_to_vote_counts(votes, 2)
      assert_equal({ 0 => {}, 1 => {}, 2 => {} }, votes)
    end
    (1..10).each do
      VoteParser.add_position_to_vote_counts(votes, 3)
      assert_equal({ 0 => {}, 1 => {}, 2 => {}, 3 => {} }, votes)
    end
  end

  def test_parse_single_vote
    votes_count = {}
    vote = ["George Washington", "John Adams", "Thomas Jefferson", "Alexander Hamilton"]

    VoteParser.parse_single_vote(votes_count, vote, 0)
    assert_equal({ 0 => { "George Washington" => 1 } }, votes_count)
    VoteParser.parse_single_vote(votes_count, vote, 0)
    assert_equal({ 0 => { "George Washington" => 2 } }, votes_count)
    VoteParser.parse_single_vote(votes_count, vote, 0)
    assert_equal({ 0 => { "George Washington" => 3 } }, votes_count)

    VoteParser.parse_single_vote(votes_count, vote, 1)
    assert_equal({ 0 => { "George Washington" => 3 }, 1 => { "John Adams" => 1 } }, votes_count)

    VoteParser.parse_single_vote(votes_count, vote, 2)
    assert_equal({ 0 => { "George Washington" => 3 }, 1 => { "John Adams" => 1 }, 2 => { "Thomas Jefferson" => 1 } }, votes_count)

    VoteParser.parse_single_vote(votes_count, vote, 3)
    assert_equal({
                     0 => { "George Washington" => 3 },
                     1 => { "John Adams" => 1 },
                     2 => { "Thomas Jefferson" => 1 },
                     3 => { "Alexander Hamilton" => 1 }
                 }, votes_count)

    VoteParser.parse_single_vote(votes_count, vote, 0)
    assert_equal({
                     0 => { "George Washington" => 4 },
                     1 => { "John Adams" => 1 },
                     2 => { "Thomas Jefferson" => 1 },
                     3 => { "Alexander Hamilton" => 1 }
                 }, votes_count)

    VoteParser.parse_single_vote(votes_count, vote, 2)
    assert_equal({
                     0 => { "George Washington" => 4 },
                     1 => { "John Adams" => 1 },
                     2 => { "Thomas Jefferson" => 2 },
                     3 => { "Alexander Hamilton" => 1 }
                 }, votes_count)
  end

  def test_validate_vote
    vote_count = {}
    used_tokens = {}
    vote = ["George Washington", "John Adams", "Thomas Jefferson", "Alexander Hamilton"]
    alt_vote = ["George Washington", "Aaron Burr", "Thomas Jefferson", "Someone Else"]
    abstain_vote = ["George Washington", "", "", ""]
    short_abstain_cote = ["George Washington"]
    token_mapping = { "abc" => "A", "bcd" => "B", "cde" => "C", "def" => "D", "efg" => "E", "fgh" => "F" }

    assert_equal('', VoteParser.validate_vote(vote_count, used_tokens, ["abc"].concat(vote), token_mapping))
    assert_equal({ "abc" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 1 },
                     2 => { "John Adams" => 1 },
                     3 => { "Thomas Jefferson" => 1 },
                     4 => { "Alexander Hamilton" => 1 }
                 }, vote_count)
    assert_equal("abc (A) voted multiple times. Using latest.\n", VoteParser.validate_vote(vote_count, used_tokens, ["abc"].concat(vote), token_mapping))
    assert_equal({ "abc" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 1 },
                     2 => { "John Adams" => 1 },
                     3 => { "Thomas Jefferson" => 1 },
                     4 => { "Alexander Hamilton" => 1 }
                 }, vote_count)
    assert_equal("abc (A) voted multiple times. Using latest.\n", VoteParser.validate_vote(vote_count, used_tokens, ["abc"].concat(vote), token_mapping))
    assert_equal({ "abc" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 1 },
                     2 => { "John Adams" => 1 },
                     3 => { "Thomas Jefferson" => 1 },
                     4 => { "Alexander Hamilton" => 1 }
                 }, vote_count)
    assert_equal('', VoteParser.validate_vote(vote_count, used_tokens, ["bcd"].concat(vote), token_mapping))
    assert_equal({ "abc" => true, "bcd" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 2 },
                     2 => { "John Adams" => 2 },
                     3 => { "Thomas Jefferson" => 2 },
                     4 => { "Alexander Hamilton" => 2 }
                 }, vote_count)
    assert_equal("bcd (B) voted multiple times. Using latest.\n", VoteParser.validate_vote(vote_count, used_tokens, ["bcd"].concat(vote), token_mapping))
    assert_equal({ "abc" => true, "bcd" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 2 },
                     2 => { "John Adams" => 2 },
                     3 => { "Thomas Jefferson" => 2 },
                     4 => { "Alexander Hamilton" => 2 }
                 }, vote_count)

    assert_equal('', VoteParser.validate_vote(vote_count, used_tokens, ["cde"].concat(alt_vote), token_mapping))
    assert_equal({ "abc" => true, "bcd" => true, "cde" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 3 },
                     2 => { "Aaron Burr" => 1, "John Adams" => 2 },
                     3 => { "Thomas Jefferson" => 3 },
                     4 => { "Alexander Hamilton" => 2, "Someone Else" => 1 }
                 }, vote_count)

    assert_equal('', VoteParser.validate_vote(vote_count, used_tokens, ["def"].concat(alt_vote), token_mapping))
    assert_equal({ "abc" => true, "bcd" => true, "cde" => true, "def" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 4 },
                     2 => { "Aaron Burr" => 2, "John Adams" => 2 },
                     3 => { "Thomas Jefferson" => 4 },
                     4 => { "Alexander Hamilton" => 2, "Someone Else" => 2 }
                 }, vote_count)

    assert_equal('', VoteParser.validate_vote(vote_count, used_tokens, ["efg"].concat(abstain_vote), token_mapping))
    assert_equal({ "abc" => true, "bcd" => true, "cde" => true, "def" => true, "efg" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 5 },
                     2 => { "Aaron Burr" => 2, "John Adams" => 2 },
                     3 => { "Thomas Jefferson" => 4 },
                     4 => { "Alexander Hamilton" => 2, "Someone Else" => 2 }
                 }, vote_count)

    assert_equal("efg (E) voted multiple times. Using latest.\n", VoteParser.validate_vote(vote_count, used_tokens, ["efg"].concat(abstain_vote), token_mapping))
    assert_equal({ "abc" => true, "bcd" => true, "cde" => true, "def" => true, "efg" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 5 },
                     2 => { "Aaron Burr" => 2, "John Adams" => 2 },
                     3 => { "Thomas Jefferson" => 4 },
                     4 => { "Alexander Hamilton" => 2, "Someone Else" => 2 }
                 }, vote_count)

    assert_equal('', VoteParser.validate_vote(vote_count, used_tokens, ["fgh"].concat(short_abstain_cote), token_mapping))
    assert_equal({ "abc" => true, "bcd" => true, "cde" => true, "def" => true, "efg" => true, "fgh" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 6 },
                     2 => { "Aaron Burr" => 2, "John Adams" => 2 },
                     3 => { "Thomas Jefferson" => 4 },
                     4 => { "Alexander Hamilton" => 2, "Someone Else" => 2 }
                 }, vote_count)

    assert_equal("fgh (F) voted multiple times. Using latest.\n", VoteParser.validate_vote(vote_count, used_tokens, ["fgh"].concat(short_abstain_cote), token_mapping))
    assert_equal({ "abc" => true, "bcd" => true, "cde" => true, "def" => true, "efg" => true, "fgh" => true }, used_tokens)
    assert_equal({
                     1 => { "George Washington" => 6 },
                     2 => { "Aaron Burr" => 2, "John Adams" => 2 },
                     3 => { "Thomas Jefferson" => 4 },
                     4 => { "Alexander Hamilton" => 2, "Someone Else" => 2 }
                 }, vote_count)
  end

  def test_generate_vote_totals
    # Messages tests
    assert_equal('', VoteParser.generate_vote_totals({}, {}, [['abc', '']], { 'abc' => 'A' }))
    assert_equal(
        "abc (A) voted multiple times. Using latest.\n",
        VoteParser.generate_vote_totals({}, { 'abc' => true }, [['abc', '']], { 'abc' => 'A' })
    )
    assert_equal(
        "abc (A) voted multiple times. Using latest.\nabc (A) voted multiple times. Using latest.\n",
        VoteParser.generate_vote_totals({}, { 'abc' => true }, [['abc', ''], ['abc', '']], { 'abc' => 'A' })
    )
    assert_equal(
        "xyz is an invalid token. Vote not counted.\nabc (A) voted multiple times. Using latest.\nabc (A) voted multiple times. Using latest.\n",
        VoteParser.generate_vote_totals({}, { 'abc' => true }, [['abc', ''], ['abc', ''], ['xyz', '']], { 'abc' => 'A' }))
    assert_equal(
        "xyz is an invalid token. Vote not counted.\nabc (A) voted multiple times. Using latest.\nabc (A) voted multiple times. Using latest.\nxyz2 is an invalid token. Vote not counted.\n",
        VoteParser.generate_vote_totals(
            {},
            { 'abc' => true },
            [['xyz2', ''], ['abc', ''], ['abc', ''], ['xyz', '']],
            { 'abc' => 'A' }
        )
    )

    #Vote Counts
    vote_counts = {}
    used_tokens = {}
    VoteParser.generate_vote_totals(
        vote_counts,
        used_tokens,
        [%w[xyz2 AVote1 BVote1], %w[abc AVote2 BVote2], %w[abc AVote3 BVote3], %w[xyz AVote4 BVote4]],
        { 'abc' => 'A' }
    )
    assert_equal({ 1 => { "AVote3" => 1 }, 2 => { "BVote3" => 1 } }, vote_counts)
    assert_equal({ "abc" => true }, used_tokens)

    vote_counts = {}
    used_tokens = {}
    VoteParser.generate_vote_totals(
        vote_counts,
        used_tokens,
        [%w[xyz2 AVote1 BVote1], %w[abc AVote2 BVote2], %w[abc AVote3 BVote3], %w[xyz AVote4 BVote4]],
        { 'abc' => 'A', 'xyz' => 'X', 'xyz2' => 'X2' }
    )
    assert_equal(
        {
            1 => { 'AVote1' => 1, "AVote3" => 1, 'AVote4' => 1 },
            2 => { 'BVote1' => 1, "BVote3" => 1, 'BVote4' => 1 }
        },
        vote_counts)
    assert_equal({ "abc" => true, 'xyz' => true, 'xyz2' => true }, used_tokens)

    vote_counts = {}
    used_tokens = {}
    warning = VoteParser.generate_vote_totals(
        vote_counts,
        used_tokens,
        [
            %w[xyz2 AVote4 BVote4],
            %w[abc AVote2 BVote2],
            %w[abc AVote3 BVote3],
            %w[xyz AVote4 BVote4],
            %w[hi AVote4 BVote3],
            %w[hi2 AVote4 BVote2],
            %w[hi3 AVote4],
            ['hi4', '', 'BVote2'],
            %w[fake hi]
        ],
        {
            'abc' => 'A',
            'bcd' => 'B',
            'hi' => 'H',
            'hi2' => 'H',
            'hi3' => 'H',
            'hi4' => 'H',
            'xyz' => 'X',
            'xyz2' => 'X2'
        }
    )
    assert_equal("fake is an invalid token. Vote not counted.\nabc (A) voted multiple times. Using latest.\n", warning)
    assert_equal(
        {
            1 => { "AVote3" => 1, 'AVote4' => 5 },
            2 => { 'BVote2' => 2, "BVote3" => 2, 'BVote4' => 2 }
        },
        vote_counts)
    assert_equal({ "abc" => true, 'hi' => true, 'hi2' => true, 'hi3' => true, 'hi4' => true, 'xyz' => true, 'xyz2' => true }, used_tokens)
  end

  def test_init
    # Standard
    vote_file = 'init_vote_test.csv'
    CSV.open(vote_file, 'w') do |f|
      f << %w[Password President VP]
      f << %w[abc You I]
      f << %w[123 Me Them]
      f << %w[fake Villain Henchman]
    end

    token_file = 'init_token_test.csv'
    CSV.open(token_file, 'w') do |f|
      f << %w[Organization Token]
      f << %w[A abc]
      f << %w[B 123]
    end

    result = VoteParser.init(vote_file, token_file)
    assert_equal([%w[abc You I], %w[123 Me Them], %w[fake Villain Henchman]], result[:Votes])
    assert_equal({ 'abc' => 'A', '123' => 'B' }, result[:TokenMapping])
    assert_equal(%w[Password President VP], result[:Cols])

    File.delete vote_file
    File.delete token_file

    # Imaginary files
    begin
      VoteParser.init('fake_csv.csv', 'another_fake_csv.csv')
    rescue SystemExit
      assert_true true
    else
      assert_true false
    end

    # Empty files
    vote_file = 'init_vote_test.csv'
    CSV.open(vote_file, 'w') do |f|
      f << %w[]
    end

    token_file = 'init_token_test.csv'
    CSV.open(token_file, 'w') do |f|
      f << %w[Organization Token]
    end

    result = VoteParser.init(vote_file, token_file)
    assert_equal([], result[:Votes])
    assert_equal({}, result[:TokenMapping])
    assert_equal([], result[:Cols])

    File.delete vote_file
    File.delete token_file
  end

  def test_process_votes
    result = VoteParser.process_votes(
        [
            %w[xyz2 AVote4 BVote4],
            %w[abc AVote2 BVote2],
            %w[abc AVote3 BVote3],
            %w[xyz AVote4 BVote4],
            %w[hi AVote4 BVote3],
            %w[hi2 AVote4 BVote2],
            %w[hi3 AVote4],
            ['hi4', '', 'BVote2'],
            %w[fake hi]
        ],
        {
            'abc' => 'A',
            'bcd' => 'B',
            'hi' => 'H',
            'hi2' => 'H',
            'hi3' => 'H',
            'hi4' => 'H',
            'xyz' => 'X',
            'xyz2' => 'X2'
        }
    )
    assert_equal("fake is an invalid token. Vote not counted.\nabc (A) voted multiple times. Using latest.\n", result[:Warning])
    assert_equal(
        {
            1 => { "AVote3" => 1, 'AVote4' => 5 },
            2 => { 'BVote2' => 2, "BVote3" => 2, 'BVote4' => 2 }
        },
        result[:VoteCounts])
    assert_equal(7, result[:TotalVoterCount])
  end
end


#noinspection RubyResolve
class TestOutputPrinter < Test::Unit::TestCase
  def test_write_election_report
    begin
      OutputPrinter.write_election_report(nil, '')
    rescue
      assert_true false
    else
      assert_true true
    end

    file_name = 'test_write_election_report.txt'
    OutputPrinter.write_election_report(
        file_name,
        'This is a fake election report that needs to be seen',
        'This is a warning that also needs to be seen'
    )

    file = File.open(file_name)
    contents = file.read
    assert_true(contents.match?(/\sThis is a fake election report that needs to be seen\s/m))
    assert_true(contents.match?(/\sThis is a warning that also needs to be seen\s/m))

    OutputPrinter.write_election_report(
        file_name,
        'This is a second fake election report that needs to be seen',
        'This is a second warning that also needs to be seen'
    )

    file = File.open(file_name)
    contents = file.read
    assert_true(contents.match?(/\sThis is a fake election report that needs to be seen\s/m))
    assert_true(contents.match?(/\sThis is a warning that also needs to be seen\s/m))
    assert_true(contents.match?(/\sThis is a second fake election report that needs to be seen\s/m))
    assert_true(contents.match?(/\sThis is a second warning that also needs to be seen\s/m))
    File.delete file
  end

  def test_ballot_entry_string
    assert_equal(
        "\t*Tom:                  100 votes (51.81%)\n",
        OutputPrinter.ballot_entry_string('Tom', 100, 51.8134715)
    )
    assert_equal(
        "\t*Tom:                    4 votes (66.67%)\n",
        OutputPrinter.ballot_entry_string('Tom', 4, 66.6666)
    )
    assert_equal(
        "\t Allison:                1 vote  (1.00%)\n",
        OutputPrinter.ballot_entry_string('Allison', 1, 1)
    )
    assert_equal(
        "\t*Allison:                1 vote  (100.00%)\n",
        OutputPrinter.ballot_entry_string('Allison', 1, 100)
    )
  end

  def test_abstention_count_string
    assert_equal('', OutputPrinter.abstention_count_string(1, 2))
    assert_equal('', OutputPrinter.abstention_count_string(0, 1))
    assert_equal("\t Abstained:              1 vote\n", OutputPrinter.abstention_count_string(10, 9))
    assert_equal("\t Abstained:             91 votes\n", OutputPrinter.abstention_count_string(100, 9))
    assert_equal("\t Abstained:           1091 votes\n", OutputPrinter.abstention_count_string(1100, 9))
  end

  def test_position_report_totals
    assert_equal(
        "\t Abstained:              1 vote\n-------------------------------------------------\n\t Total:                193 votes\n\n",
        OutputPrinter.position_report_totals(193, 192)
    )
    assert_equal(
        "\t Abstained:            100 votes\n-------------------------------------------------\n\t Total:                193 votes\n\n",
        OutputPrinter.position_report_totals(193, 93)
    )
    assert_equal(
        "\t Abstained:              1 vote\n-------------------------------------------------\n\t Total:                  1 vote\n\n",
        OutputPrinter.position_report_totals(1, 0)
    )
    assert_equal(
        "-------------------------------------------------\n\t Total:                  1 vote\n\n",
        OutputPrinter.position_report_totals(1, 1)
    )
    assert_equal(
        "-------------------------------------------------\n\t Total:               1000 votes\n\n",
        OutputPrinter.position_report_totals(1000, 1000)
    )
  end

  def test_position_report_indiv
    result = OutputPrinter.position_report_individuals(
        6,
        5,
        { "AVote3" => 1, 'AVote4' => 4 }
    )

    expected = "\t*AVote4:                 4 votes (66.67%)\n" +
        "\t AVote3:                 1 vote  (16.67%)\n" +
        "\t Abstained:              1 vote\n" +
        "-------------------------------------------------\n" +
        "\t Total:                  6 votes\n\n"
    assert_equal(expected, result)

    result = OutputPrinter.position_report_individuals(
        6,
        6,
        { "AVote3" => 2, 'AVote4' => 4 }
    )

    expected = "\t*AVote4:                 4 votes (66.67%)\n" +
        "\t AVote3:                 2 votes (33.33%)\n" +
        "-------------------------------------------------\n" +
        "\t Total:                  6 votes\n\n"
    assert_equal(expected, result)

    result = OutputPrinter.position_report_individuals(
        1000,
        6,
        { "AVote3" => 2, 'AVote4' => 4 }
    )

    expected = "\t AVote4:                 4 votes (0.40%)\n" +
        "\t AVote3:                 2 votes (0.20%)\n" +
        "\t Abstained:            994 votes\n" +
        "-------------------------------------------------\n" +
        "\t Total:               1000 votes\n\n"
    assert_equal(expected, result)

    result = OutputPrinter.position_report_individuals(
        1000,
        602,
        { "AVote3" => 2, 'AVote4' => 600 }
    )

    expected = "\t*AVote4:               600 votes (60.00%)\n" +
        "\t AVote3:                 2 votes (0.20%)\n" +
        "\t Abstained:            398 votes\n" +
        "-------------------------------------------------\n" +
        "\t Total:               1000 votes\n\n"
    assert_equal(expected, result)
  end

  def test_sum_position_votes
    assert_equal(602, OutputPrinter.sum_position_votes({ "AVote3" => 2, 'AVote4' => 600 }))
    assert_equal(800, OutputPrinter.sum_position_votes({ "AVote3" => 200, 'AVote4' => 600 }))
    assert_equal(0, OutputPrinter.sum_position_votes({ "AVote3" => 0, 'AVote4' => 0 }))
    assert_equal(0, OutputPrinter.sum_position_votes({}))
    assert_equal(
        1204,
        OutputPrinter.sum_position_votes(
            { "AVote1" => 2, 'AVote2' => 600, "AVote3" => 2, 'AVote4' => 600 }
        )
    )
    assert_equal(
        1400,
        OutputPrinter.sum_position_votes(
            {
                "AVote1" => 2,
                'AVote2' => 600,
                "AVote3" => 2,
                'AVote4' => 600,
                'AVote5' => 100,
                'AVote6' => 46,
                'AVote7' => 50
            }
        )
    )
  end

  def test_majority_reached
    assert_true(OutputPrinter.majority_reached?(100, { "AVote3" => 20, 'AVote4' => 60 }))
    assert_true(OutputPrinter.majority_reached?(100, { 'AVote4' => 100 }))
    assert_true(OutputPrinter.majority_reached?(100, { "AVote3" => 49, 'AVote4' => 51 }))
    assert_true(OutputPrinter.majority_reached?(100, { "AVote3" => 99, 'AVote4' => 1 }))
    assert_true(OutputPrinter.majority_reached?(1, { "AVote3" => 0, 'AVote4' => 1 }))
    assert_true(OutputPrinter.majority_reached?(3, { "AVote3" => 2, 'AVote4' => 1 }))
    assert_true(OutputPrinter.majority_reached?(100, { "AVote1" => 2, "AVote2" => 2, "AVote3" => 2, 'AVote4' => 1, 'AVote5' => 1, 'AVote6' => 1, 'AVote7' => 1, 'AVote8' => 90 }))
    assert_true(OutputPrinter.majority_reached?(1, { "AVote1" => 1 }))

    assert_false(OutputPrinter.majority_reached?(100, { "AVote1" => 2, "AVote2" => 2, "AVote3" => 2, 'AVote4' => 1, 'AVote5' => 1, 'AVote6' => 1, 'AVote7' => 1, 'AVote8' => 9 }))
    assert_false(OutputPrinter.majority_reached?(100, {}))
    assert_false(OutputPrinter.majority_reached?(0, {}))
    assert_false(OutputPrinter.majority_reached?(2, { "AVote1" => 1 }))
  end

  def test_position_report
    assert_equal(
        "President\n" +
            "\t*AVote4:                60 votes (60.00%)\n" +
            "\t AVote3:                20 votes (20.00%)\n" +
            "\t Abstained:             20 votes\n" +
            "-------------------------------------------------\n" +
            "\t Total:                100 votes",
        OutputPrinter.position_report(
            100,
            'President',
            { "AVote3" => 20, 'AVote4' => 60 }
        ).strip
    )

    assert_equal(
        "President (No Majority)\n" +
            "\t AVote3:                20 votes (20.00%)\n" +
            "\t AVote4:                20 votes (20.00%)\n" +
            "\t Abstained:             60 votes\n" +
            "-------------------------------------------------\n" +
            "\t Total:                100 votes",
        OutputPrinter.position_report(
            100,
            'President',
            { "AVote4" => 20, 'AVote3' => 20 }
        ).strip
    )

    assert_equal(
        "President (No Majority)\n" +
            "\t AVote4:                21 votes (21.00%)\n" +
            "\t AVote2:                20 votes (20.00%)\n" +
            "\t AVote3:                20 votes (20.00%)\n" +
            "\t Abstained:             39 votes\n" +
            "-------------------------------------------------\n" +
            "\t Total:                100 votes",
        OutputPrinter.position_report(
            100,
            'President',
            { "AVote2" => 20, "AVote3" => 20, 'AVote4' => 21 }
        ).strip
    )
  end

  def test_vote_report
    vote_counts = {
        1 => { "George Washington" => 6 },
        2 => { "Aaron Burr" => 4, "John Adams" => 2 },
        3 => { "Thomas Jefferson" => 3 },
        4 => { "Alexander Hamilton" => 3, "Someone Else" => 2, "Another Person" => 1 }
    }
    column_headers = %w[Password President VP Secretary Treasurer]
    vote_count = 6
    expected = "President\n" +
        "\t*George Washington:      6 votes (100.00%)\n" +
        "-------------------------------------------------\n" +
        "\t Total:                  6 votes\n\n\n" +
        "VP\n" +
        "\t*Aaron Burr:             4 votes (66.67%)\n" +
        "\t John Adams:             2 votes (33.33%)\n" +
        "-------------------------------------------------\n" +
        "\t Total:                  6 votes\n\n\n" +
        "Secretary (No Majority)\n" +
        "\t Thomas Jefferson:       3 votes (50.00%)\n" +
        "\t Abstained:              3 votes\n" +
        "-------------------------------------------------\n" +
        "\t Total:                  6 votes\n\n\n" +
        "Treasurer (No Majority)\n" +
        "\t Alexander Hamilton:     3 votes (50.00%)\n" +
        "\t Someone Else:           2 votes (33.33%)\n" +
        "\t Another Person:         1 vote  (16.67%)\n" +
        "-------------------------------------------------\n" +
        "\t Total:                  6 votes"
    assert_equal(expected, OutputPrinter.vote_report(vote_count, column_headers, vote_counts).strip)
  end
end
