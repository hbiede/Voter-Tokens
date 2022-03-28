# Author: Hundter Biede (hbiede.com)
# Version: 1.2
# License: MIT
require_relative '../gen_tokens'
require_relative './helper'

def assert_latex_equal(file_name, expected_tex)
  begin
    assert_true(File.exist?("#{file_name}.tex"))
    assert_true(File.exist?("#{file_name}.pdf"))
    file = File.open("#{file_name}.tex")
    assert_equal(expected_tex, file.read)
  ensure
    File.delete "#{file_name}.aux"
    File.delete "#{file_name}.log"
    File.delete "#{file_name}.pdf"
    File.delete "#{file_name}.tex"
  end
end

#noinspection RubyResolve
class TestPDFWriter < Test::Unit::TestCase
  def test_write_latex_to_pdf
    PDFWriter.write_latex_to_pdf('George Washington', "\\documentclass{article}\\begin{document}Empty\\end{document}")
    assert_latex_equal("GeorgeWashington", "\\documentclass{article}\\begin{document}Empty\\end{document}")
  end

  def test_create_org_pdf
    assert_equal("PDF generated for John Adams\n", PDFWriter.create_org_pdf("\\documentclass{article}\n\\begin{document}\nREPLACESCHOOL\n\\end{document}", "John Adams", ["Password 1", "Password 2"]))
    assert_latex_equal('JohnAdams', "\\documentclass{article}\n\\begin{document}\nJohn Adams\n\\end{document}")

    assert_equal("PDF generated for John Adams\n", PDFWriter.create_org_pdf("\\documentclass{article}\n\\begin{document}\nREPLACESCHOOL, REPLACESCHOOL\n\\end{document}", "John Adams", ["Password 1", "Password 2"]))
    assert_latex_equal('JohnAdams', "\\documentclass{article}\n\\begin{document}\nJohn Adams, John Adams\n\\end{document}")

    assert_equal("PDF generated for Thomas Jefferson\n", PDFWriter.create_org_pdf("\\documentclass{article}\n\\begin{document}\nREPLACEPW\n\\end{document}", "Thomas Jefferson", ["Password 1", "Password 2"]))
    assert_latex_equal('ThomasJefferson', "\\documentclass{article}\n\\begin{document}\nPassword 1 \\\\\nPassword 2\n\\end{document}")

    assert_equal("PDF generated for Thomas Jefferson 2\n", PDFWriter.create_org_pdf("\\documentclass{article}\n\\begin{document}\nREPLACEPW, REPLACEPW\n\\end{document}", "Thomas Jefferson 2", ["Password 1", "Password 2"]))
    assert_latex_equal('ThomasJefferson2', "\\documentclass{article}\n\\begin{document}\nPassword 1 \\\\\nPassword 2, Password 1 \\\\\nPassword 2\n\\end{document}")
  end

  def test_create_pdfs
    tokens = {
        'James Madison' => %w[1 2],
        "James Monroe" => %w[3 4],
        "John Q Adams" => %w[5 6]
    }
    begin
      assert_equal("3 PDFs generated", PDFWriter.create_pdfs(tokens, "\\documentclass{article}\\begin{document}Empty\\end{document}"))
      assert_true(File.exist? "pdfs/JamesMadison.pdf")
      assert_true(File.exist? "pdfs/JamesMonroe.pdf")
      assert_true(File.exist? "pdfs/JohnQAdams.pdf")
      assert_false(File.exist? "pdfs/JohnQAdams.aux")
      assert_false(File.exist? "pdfs/JohnQAdams.log")
      assert_false(File.exist? "pdfs/JohnQAdams.out")
      assert_false(File.exist? "pdfs/JohnQAdams.tex")
    ensure
      File.delete "pdfs/JamesMonroe.pdf"
      File.delete "pdfs/JamesMadison.pdf"
      File.delete "pdfs/JohnQAdams.pdf"
    end
  end
end

#noinspection RubyResolve
class TestTokenGenerator < Test::Unit::TestCase
  def test_write_tokens_to_csv
    csv_file = "test_tokens.csv"
    TokenGenerator.write_tokens_to_csv({
                                           George: %w[1 2 3],
                                           John: %w[4 5 6],
                                           Thomas: %w[7 8 9],
                                       }, csv_file)
    assert_equal([
                     %w[Organization Token],
                     %w[George 1],
                     %w[George 2],
                     %w[George 3],
                     %w[John 4],
                     %w[John 5],
                     %w[John 6],
                     %w[Thomas 7],
                     %w[Thomas 8],
                     %w[Thomas 9],
                 ], CSV.read(csv_file))
    File.delete(csv_file)
  end

  def test_read_delegate_csv
    csv_file = "test_tokens.csv"
    TokenGenerator.write_tokens_to_csv({
                                           George: %w[1 2 3],
                                           John: %w[4 5 6],
                                           Thomas: %w[7 8 9],
                                           James: []
                                       }, csv_file)
    assert_equal([
                     %w[Organization Token],
                     %w[George 1],
                     %w[George 2],
                     %w[George 3],
                     %w[John 4],
                     %w[John 5],
                     %w[John 6],
                     %w[Thomas 7],
                     %w[Thomas 8],
                     %w[Thomas 9],
                 ], TokenGenerator.read_delegate_csv(csv_file))
    File.delete(csv_file)

    begin
      TokenGenerator.read_delegate_csv("fake_csv.csv")
    rescue SystemExit
      assert_true true
    else
      assert_false true
    end
  end

  def test_random_string
    (1..10).each do |i|
      assert_equal(i, TokenGenerator.random_string(i).length)
      assert_equal(i, TokenGenerator.random_string(i).length)
      assert_equal(i, TokenGenerator.random_string(i).length)
      assert_false(TokenGenerator.random_string(i).include?(' '))
    end
  end

  def test_gen_token

    full_token_list = {
        :Org => CHARS[0...CHARS.length - 1],
    }

    # Will fail on valid code approximately 1 in every 60^5 times
    assert_true(CHARS[(CHARS.length - 1)...CHARS.length].include? TokenGenerator.gen_token(full_token_list, 1))
    assert_true(CHARS[(CHARS.length - 1)...CHARS.length].include? TokenGenerator.gen_token(full_token_list, 1))
    assert_true(CHARS[(CHARS.length - 1)...CHARS.length].include? TokenGenerator.gen_token(full_token_list, 1))
    assert_true(CHARS[(CHARS.length - 1)...CHARS.length].include? TokenGenerator.gen_token(full_token_list, 1))
    assert_true(CHARS[(CHARS.length - 1)...CHARS.length].include? TokenGenerator.gen_token(full_token_list, 1))
  end

  def test_process_chapter
    lines = [
        ["George Washington", 3],
        ["John Adams", 4],
        ["Thomas Jefferson", 7],
    ]
    columns = {
        Org: 0,
        Delegates: 1,
    }
    all_tokens = {}
    lines.each do |line|
      TokenGenerator.process_chapter(line, columns, all_tokens)
      # noinspection RubyNilAnalysis
      assert_equal(line[1], all_tokens.fetch(line[0]).length)
    end
  end

  def test_determine_header_columns
    columns = {
        Org: 0,
        Delegates: 0,
    }
    TokenGenerator.determine_header_columns(columns, %w[school delegates])
    assert_equal(0, columns[:Org])
    assert_equal(1, columns[:Delegates])

    TokenGenerator.determine_header_columns(columns, %w[delegate schools])
    assert_equal(1, columns[:Org])
    assert_equal(0, columns[:Delegates])

    TokenGenerator.determine_header_columns(columns, %w[organizations voters])
    assert_equal(0, columns[:Org])
    assert_equal(1, columns[:Delegates])

    TokenGenerator.determine_header_columns(columns, %w[organization voter])
    assert_equal(0, columns[:Org])
    assert_equal(1, columns[:Delegates])

    TokenGenerator.determine_header_columns(columns, %w[chapters voters])
    assert_equal(0, columns[:Org])
    assert_equal(1, columns[:Delegates])

    TokenGenerator.determine_header_columns(columns, %w[voter chapter])
    assert_equal(1, columns[:Org])
    assert_equal(0, columns[:Delegates])

    TokenGenerator.determine_header_columns(columns, %w[name voters])
    assert_equal(0, columns[:Org])
    assert_equal(1, columns[:Delegates])

    TokenGenerator.determine_header_columns(columns, %w[delegate names])
    assert_equal(1, columns[:Org])
    assert_equal(0, columns[:Delegates])

    TokenGenerator.determine_header_columns(columns, %w[nope nope])
    assert_equal(nil, columns[:Org])
    assert_equal(nil, columns[:Delegates])
  end

  def test_parse_organizations
    all_tokens = {}
    lines = [
        %w[Organizations Delegates],
        %w[Test 1],
        %w[Test2 10],
    ]
    TokenGenerator.parse_organizations(all_tokens, lines)
    assert_equal(1, all_tokens["Test"].length)
    assert_equal(10, all_tokens["Test2"].length)

    begin
      TokenGenerator.parse_organizations({}, [["", ""], ["", ""]])
    rescue SystemExit
      assert_true true
    else
      assert_false true
    end
  end

  def test_get_token_count_report
    assert_equal("3 token sets generated (9 total tokens)\n\n", TokenGenerator.get_token_count_report(
        {
            George: %w[1 2 3],
            John: %w[4 5 6],
            Thomas: %w[7 8 9],
            James: nil,
            James2: [],
        }
    ))
  end
end
