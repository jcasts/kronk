require 'test/test_helper'

class TestResponse < Test::Unit::TestCase

  def setup
    @html_resp  = Kronk::Request.retrieve_file "test/mocks/200_response.txt"
    @json_resp  = Kronk::Request.retrieve_file "test/mocks/200_response.json"
    @plist_resp = Kronk::Request.retrieve_file "test/mocks/200_response.plist"
    @xml_resp   = Kronk::Request.retrieve_file "test/mocks/200_response.xml"
  end


  def test_read_new
    File.open "test/mocks/200_response.txt", "r" do |file|
      resp = Kronk::Response.read_new file


      expected_header = "#{mock_200_response.split("\r\n\r\n", 2)[0]}\r\n"

      assert Net::HTTPResponse === resp
      assert_equal mock_200_response, resp.raw
      assert_equal expected_header, resp.raw_header
    end
  end


  def test_read_raw_from
    resp   = mock_200_response
    chunks = [resp[0..123], resp[124..200], resp[201..-1]]
    chunks = chunks.map{|c| "-> #{c.inspect}"}
    str = [chunks[0], "<- reading 123 bytes", chunks[1], chunks[2]].join "\n"
    str = "<- \"mock debug request\"\n#{str}\nread 123 bytes"

    io = StringIO.new str

    req, resp, bytes = Kronk::Response.read_raw_from io

    assert_equal "mock debug request", req
    assert_equal mock_200_response, resp
    assert_equal 123, bytes
  end


  def test_parsed_body_json
    raw = File.read "test/mocks/200_response.json"
    expected = JSON.parse raw.split("\r\n\r\n")[1]

    assert_equal expected, @json_resp.parsed_body
    assert_equal @xml_resp.parsed_body, @json_resp.parsed_body

    assert_raises RuntimeError do
      @json_resp.parsed_body Kronk::PlistParser
    end
  end


  def test_parsed_body_plist
    raw = File.read "test/mocks/200_response.plist"
    expected = Kronk::PlistParser.parse raw.split("\r\n\r\n")[1]

    assert_equal expected, @plist_resp.parsed_body
    assert_equal @json_resp.parsed_body, @plist_resp.parsed_body
  end


  def test_parsed_body_xml
    raw = File.read "test/mocks/200_response.xml"
    expected = Kronk::XMLParser.parse raw.split("\r\n\r\n")[1]

    assert_equal expected, @xml_resp.parsed_body
    assert_equal @json_resp.parsed_body, @xml_resp.parsed_body
  end


  def test_parsed_body_missing_parser
    assert_raises Kronk::Response::MissingParser do
      @html_resp.parsed_body
    end
  end


  def test_parsed_body_bad_parser
    assert_raises JSON::ParserError do
      @html_resp.parsed_body JSON
    end
  end


  def test_parsed_header
    assert_equal @json_resp.to_hash, @json_resp.parsed_header

    assert_equal({'content-type' => ["application/json; charset=utf-8"]},
                @json_resp.parsed_header('Content-Type'))

    assert_equal({'date'         => ["Fri, 03 Dec 2010 21:49:00 GMT"],
                  'content-type' => ["application/json; charset=utf-8"]},
                @json_resp.parsed_header(['Content-Type', 'Date']))

    assert_nil @json_resp.parsed_header(false)
    assert_nil @json_resp.parsed_header(nil)
  end


  def test_raw_header
    assert_equal "#{@json_resp.raw.split("\r\n\r\n")[0]}\r\n",
                 @json_resp.raw_header

    assert_equal "Content-Type: application/json; charset=utf-8\r\n",
                 @json_resp.raw_header('Content-Type')

    assert_equal "Date: Fri, 03 Dec 2010 21:49:00 GMT\r\nContent-Type: application/json; charset=utf-8\r\n",
                @json_resp.raw_header(['Content-Type', 'Date'])

    assert_nil @json_resp.raw_header(false)
    assert_nil @json_resp.raw_header(nil)
  end


  def test_selective_string
    body = @json_resp.raw.split("\r\n\r\n")[1]

    assert_equal body,
                 @json_resp.selective_string

    assert_nil @json_resp.selective_string(:no_body => true)

    assert_equal "#{@json_resp.raw.split("\r\n\r\n")[0]}\r\n",
                 @json_resp.selective_string(:no_body => true,
                  :with_headers => true)

    expected = "Content-Type: application/json; charset=utf-8\r\n\r\n#{body}"
    assert_equal expected,
                 @json_resp.selective_string(:with_headers => "Content-Type")

    expected = "Date: Fri, 03 Dec 2010 21:49:00 GMT\r\nContent-Type: application/json; charset=utf-8\r\n\r\n#{body}"
    assert_equal expected,
                 @json_resp.selective_string(
                    :with_headers => ["Content-Type", "Date"])

    expected = "Date: Fri, 03 Dec 2010 21:49:00 GMT\r\nContent-Type: application/json; charset=utf-8\r\n"
    assert_equal expected,
                 @json_resp.selective_string(:no_body => true,
                    :with_headers => ["Content-Type", "Date"])
  end


  def test_selective_data
  end
end
