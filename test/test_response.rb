require 'test/test_helper'

class TestResponse < Test::Unit::TestCase

  def setup
    @html_resp  = Kronk::Response.read_file "test/mocks/200_response.txt"
    @json_resp  = Kronk::Response.read_file "test/mocks/200_response.json"
    @plist_resp = Kronk::Response.read_file "test/mocks/200_response.plist"
    @xml_resp   = Kronk::Response.read_file "test/mocks/200_response.xml"
  end


  def test_new_from_one_line_io
    io   = StringIO.new "just this one line!"
    resp = Kronk::Response.new io

    assert_equal "just this one line!", resp.body
    enc = "".encoding rescue "UTF-8"
    assert_equal ["text/html; charset=#{enc}"], resp['Content-Type']
  end


  def test_read_file
    resp = Kronk::Response.read_file "test/mocks/200_response.txt"

    expected_header = "#{mock_200_response.split("\r\n\r\n", 2)[0]}\r\n"

    assert Net::HTTPResponse === resp.instance_variable_get("@_res")
    assert_equal mock_200_response, resp.raw
    assert_equal expected_header, resp.raw_header
  end


  def test_read_raw_from
    resp   = mock_200_response
    chunks = [resp[0..123], resp[124..200], resp[201..-1]]
    chunks = chunks.map{|c| "-> #{c.inspect}"}
    str = [chunks[0], "<- reading 123 bytes", chunks[1], chunks[2]].join "\n"
    str = "<- \"mock debug request\"\n#{str}\nread 123 bytes"

    io = StringIO.new str

    resp = Kronk::Response.new mock_200_response
    req, resp, bytes = resp.send :read_raw_from, io

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


  def test_parsed_body_string_parser
    raw = File.read "test/mocks/200_response.json"
    expected = JSON.parse raw.split("\r\n\r\n")[1]

    assert_equal expected, @json_resp.parsed_body

    assert_raises RuntimeError do
      @json_resp.parsed_body 'PlistParser'
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
  end


  def test_selective_string_no_body
    body = @json_resp.raw.split("\r\n\r\n")[1]

    assert_nil @json_resp.selective_string(:no_body => true)

    assert_equal "#{@json_resp.raw.split("\r\n\r\n")[0]}\r\n",
                 @json_resp.selective_string(:no_body => true,
                  :with_headers => true)
  end


  def test_selective_string_single_header
    body = @json_resp.raw.split("\r\n\r\n")[1]

    expected = "Content-Type: application/json; charset=utf-8\r\n\r\n#{body}"
    assert_equal expected,
                 @json_resp.selective_string(:with_headers => "Content-Type")
  end


  def test_selective_multiple_headers
    body = @json_resp.raw.split("\r\n\r\n")[1]

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
    body = JSON.parse @json_resp.body
    head = @json_resp.to_hash

    assert_equal body, @json_resp.selective_data

    assert_nil @json_resp.selective_data(:no_body => true)

    assert_equal "#{@json_resp.raw.split("\r\n\r\n")[0]}\r\n",
                 @json_resp.selective_string(:no_body => true,
                  :with_headers => true)
  end


  def test_selective_data_parser
    assert_raises RuntimeError do
      @json_resp.selective_data :parser => Kronk::PlistParser
    end

    assert @json_resp.selective_data(:parser => JSON)
  end


  def test_selective_data_single_header
    body = JSON.parse @json_resp.body
    expected =
      [{'content-type' => ['application/json; charset=utf-8']}, body]

    assert_equal expected,
                 @json_resp.selective_data(:with_headers => "Content-Type")
  end


  def test_selective_data_multiple_headers
    body = JSON.parse @json_resp.body
    expected =
      [{'content-type' => ['application/json; charset=utf-8'],
        'date'         => ["Fri, 03 Dec 2010 21:49:00 GMT"]
      }, body]

    assert_equal expected,
                 @json_resp.selective_data(
                    :with_headers => ["Content-Type", "Date"])
  end


  def test_selective_data_no_body
    body = JSON.parse @json_resp.body
    expected =
      [{'content-type' => ['application/json; charset=utf-8'],
        'date'         => ["Fri, 03 Dec 2010 21:49:00 GMT"]
      }]

    assert_equal expected,
                 @json_resp.selective_data(:no_body => true,
                    :with_headers => ["Content-Type", "Date"])
  end


  def test_selective_data_only_data
    expected = {"business"        => {"id" => "1234"},
                "original_request"=> {"id"=>"1234"}}

    assert_equal expected,
      @json_resp.selective_data(:only_data => "**/id")
  end


  def test_selective_data_multiple_only_data
    expected = {"business"    => {"id" => "1234"},
                "request_id"  => "mock_rid"}

    assert_equal expected,
      @json_resp.selective_data(:only_data => ["business/id", "request_id"])
  end


  def test_selective_data_ignore_data
    expected = JSON.parse @json_resp.body
    expected['business'].delete 'id'
    expected['original_request'].delete 'id'

    assert_equal expected,
      @json_resp.selective_data(:ignore_data => "**/id")
  end


  def test_selective_data_multiple_ignore_data
    expected = JSON.parse @json_resp.body
    expected['business'].delete 'id'
    expected.delete 'request_id'

    assert_equal expected,
      @json_resp.selective_data(:ignore_data => ["business/id", "request_id"])
  end


  def test_selective_data_collected_and_ignored
    expected = {"business" => {"id" => "1234"}}

    assert_equal expected,
      @json_resp.selective_data(:only_data => "**/id",
        :ignore_data => "original_request")
  end


  def test_redirect?
    res = Kronk::Response.new mock_301_response
    assert res.redirect?

    res = Kronk::Response.new mock_302_response
    assert res.redirect?

    res = Kronk::Response.new mock_200_response
    assert !res.redirect?
  end


  def test_follow_redirect
    res1 = Kronk::Response.new mock_301_response
    assert res1.redirect?

    expect_request "GET", "http://www.google.com/"
    res2 = res1.follow_redirect

    assert_equal mock_200_response, res2.raw
  end


  def test_force_encoding
    return unless "".respond_to? :encoding

    res = Kronk::Response.new mock_200_response
    expected_encoding = Encoding.find "ISO-8859-1"

    assert_equal expected_encoding, res.encoding
    assert_equal expected_encoding, res.body.encoding
    assert_equal expected_encoding, res.raw.encoding

    res.force_encoding "utf-8"
    expected_encoding = Encoding.find "utf-8"

    assert_equal expected_encoding, res.encoding
    assert_equal expected_encoding, res.body.encoding
    assert_equal expected_encoding, res.raw.encoding
  end


  def test_stringify_string
    str = Kronk::Response.read_file("test/mocks/200_response.json").stringify
    expected = <<-STR
{
"business" => {
 "address" => "3845 Rivertown Pkwy SW Ste 500",
 "city" => "Grandville",
 "description" => {
  "additional_urls" => [
   {
    "destination" => "http://example.com",
    "url_click" => "http://example.com"
    }
   ],
  "general_info" => "<p>A Paint Your Own Pottery Studios..</p>",
  "op_hours" => "Fri 1pm-7pm, Sat 10am-6pm, Sun 1pm-4pm, Appointments Available",
  "payment_text" => "DISCOVER, AMEX, VISA, MASTERCARD",
  "slogan" => "<p>Pottery YOU dress up</p>"
  },
 "distance" => 0.0,
 "has_detail_page" => true,
 "headings" => [
  "Pottery"
  ],
 "id" => "1234",
 "impression_id" => "mock_iid",
 "improvable" => true,
 "latitude" => 42.882561,
 "listing_id" => "1234",
 "listing_type" => "free",
 "longitude" => -85.759586,
 "mappable" => true,
 "name" => "Naked Plates",
 "omit_address" => false,
 "omit_phone" => false,
 "phone" => "6168055326",
 "rateable" => true,
 "rating_count" => 0,
 "red_listing" => false,
 "state" => "MI",
 "website" => "http://example.com",
 "year_established" => "1996",
 "zip" => "49418"
 },
"original_request" => {
 "id" => "1234"
 },
"request_id" => "mock_rid"
}
STR
    assert_equal expected.strip, str
  end


  def test_stringify_raw
    str = Kronk::Response.
      read_file("test/mocks/200_response.json").stringify :raw => 1

    expected = File.read("test/mocks/200_response.json").split("\r\n\r\n")[1]
    assert_equal expected, str
  end


  def test_stringify_struct
    str = Kronk::Response.read_file("test/mocks/200_response.json").
            stringify :struct => true

    expected = JSON.parse \
      File.read("test/mocks/200_response.json").split("\r\n\r\n")[1]

    expected = Kronk::Diff.ordered_data_string expected, true

    assert_equal expected, str
  end


  def test_stringify_missing_parser
    str = Kronk::Response.read_file("test/mocks/200_response.txt").stringify
    expected = File.read("test/mocks/200_response.txt").split("\r\n\r\n")[1]

    assert_equal expected, str
  end


  def test_success?
    resp = Kronk::Response.read_file("test/mocks/200_response.txt")
    assert resp.success?

    resp = Kronk::Response.read_file("test/mocks/302_response.txt")
    assert !resp.success?
  end
end
