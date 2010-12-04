require 'test/test_helper'

class TestResponseDiff < Test::Unit::TestCase

  def setup
    @ddiff = Kronk::ResponseDiff.retrieve_new "test/mocks/200_response.json",
                                              "test/mocks/200_response.xml"

    @rdiff = Kronk::ResponseDiff.retrieve_new "test/mocks/200_response.txt",
                                              "test/mocks/301_response.txt"
  end


  def test_retrieve_new
    rdiff = Kronk::ResponseDiff.retrieve_new "test/mocks/200_response.txt",
                                             "test/mocks/301_response.txt",
                                             :ignore_data => "foo",
                                             :ignore_headers => "bar"

    assert_equal File.read("test/mocks/200_response.txt"), rdiff.resp1.raw
    assert_equal File.read("test/mocks/301_response.txt"), rdiff.resp2.raw
    assert_equal "foo", rdiff.ignore_data
    assert_equal "bar", rdiff.ignore_headers
  end


  def test_new
    f1 = File.open("test/mocks/200_response.txt", "r")
    f2 = File.open("test/mocks/301_response.txt", "r")

    resp1 = Kronk::Response.read_new f1
    resp2 = Kronk::Response.read_new f2

    f1.close
    f2.close

    rdiff = Kronk::ResponseDiff.new resp1, resp2,
                                    :ignore_data => "foo",
                                    :ignore_headers => "bar"

    assert_equal resp1, rdiff.resp1
    assert_equal resp2, rdiff.resp2
    assert_equal "foo", rdiff.ignore_data
    assert_equal "bar", rdiff.ignore_headers
  end


  def test_data_diff
    raw = File.read "test/mocks/200_response.json"
    data = JSON.parse raw.split("\r\n\r\n", 2)[1]

    expected_ary = [
      "[", "{", " \"cache-control\" => [",
      "  \"private, max-age=0, must-revalidate\",",
      "  ],",
      " \"connection\"    => [",
      "  \"keep-alive\",", "  ],",
      " \"content-type\"  => [",
      [["  \"application/json; charset=utf-8\","],
       ["  \"application/xml; charset=utf-8\","]],
      "  ],",
      " \"date\"          => [",
      "  \"Fri, 03 Dec 2010 21:49:00 GMT\",",
      "  ],",
      " \"etag\"          => [",
      "  \"\\\"mock_etag\\\"\",",
      "  ],", " \"keep-alive\"    => [",
      "  \"timeout=20\",", "  ],",
      " \"server\"        => [",
      "  \"nginx/0.6.39\",",
      "  ],",
      " \"status\"        => [",
      "  \"200 OK\",",
      "  ],",
      " \"x-runtime\"     => [",
      "  \"45\",",
      "  ]",
      " },",
      "{",
      " \"business\"         => {",
      "  \"address\"          => \"3845 Rivertown Pkwy SW Ste 500\",",
      "  \"city\"             => \"Grandville\",",
      "  \"description\"      => {",
      "   \"additional_urls\" => [",
      "    {",
      "     \"destination\" => \"http://example.com\",",
      "     \"url_click\"   => \"http://example.com\"",
      "     },",
      "    ],",
      "   \"general_info\"    => \"<p>A Paint Your Own Pottery Studios..</p>\",",
      "   \"op_hours\"        => \"Fri 1pm-7pm, Sat 10am-6pm, Sun 1pm-4pm, Appointments Available\",",
      "   \"payment_text\"    => \"DISCOVER, AMEX, VISA, MASTERCARD\",",
      "   \"slogan\"          => \"<p>Pottery YOU dress up</p>\"", "   },",
      "  \"distance\"         => 0.0,",
      "  \"has_detail_page\"  => true,",
      "  \"headings\"         => [",
      "   \"Pottery\",", "   ],",
      "  \"id\"               => \"1234\",",
      "  \"impression_id\"    => \"mock_iid\",",
      "  \"improvable\"       => true,",
      "  \"latitude\"         => 42.882561,",
      "  \"listing_id\"       => \"1234\",",
      "  \"listing_type\"     => \"free\",",
      "  \"longitude\"        => -85.759586,",
      "  \"mappable\"         => true,",
      "  \"name\"             => \"Naked Plates\",",
      "  \"omit_address\"     => false,",
      "  \"omit_phone\"       => false,",
      "  \"phone\"            => \"6168055326\",",
      "  \"rateable\"         => true,",
      "  \"rating_count\"     => 0,",
      "  \"red_listing\"      => false,",
      "  \"state\"            => \"MI\",",
      "  \"website\"          => \"http://example.com\",",
      "  \"year_established\" => \"1996\",",
      "  \"zip\"              => \"49418\"", "  },",
      " \"original_request\" => {",
      "  \"id\" => \"1234\"",
      "  },",
      " \"request_id\"       => \"mock_rid\"", " },",
      "]"]

    diff = @ddiff.data_diff

    assert_equal expected_ary, diff.to_a
    assert_equal \
      @ddiff.ordered_data_string([@ddiff.resp1.to_hash, data]), diff.str1
    assert_equal \
      @ddiff.ordered_data_string([@ddiff.resp2.to_hash, data]), diff.str2
  end


  def test_data_diff_options
    options = "mock_options"
    @ddiff.expects(:data_response).with(@ddiff.resp1, options).returns "resp1"
    @ddiff.expects(:data_response).with(@ddiff.resp2, options).returns "resp2"

    diff = @ddiff.data_diff options
    assert Kronk::Diff === diff, "Diff response must be a Kronk::Diff instance"
    assert_equal [[["resp1".inspect],["resp2".inspect]]], diff.to_a
  end


  def test_data_response_ignore_data_all
    assert_equal [],
      @ddiff.data_response(@ddiff.resp1, :ignore_data => true,
                                         :ignore_headers => true)
  end


  def test_data_response_ignore_data_single
    raw = File.read "test/mocks/200_response.json"
    data = JSON.parse raw.split("\r\n\r\n", 2)[1]

    data['business'].delete 'website'
    data['business'].delete 'phone'

    assert_equal [@ddiff.resp1.to_hash, data],
      @ddiff.data_response(@ddiff.resp1, :ignore_data => "*/website|phone")
  end


  def test_data_response_ignore_data_many
    raw = File.read "test/mocks/200_response.json"
    data = JSON.parse raw.split("\r\n\r\n", 2)[1]

    data['business'].delete 'website'
    data['business'].delete 'phone'
    data['business']['description'].delete 'op_hours'

    assert_equal [@ddiff.resp1.to_hash, data],
      @ddiff.data_response(@ddiff.resp1,
        :ignore_data => ["*/website|phone", "**/op_hours"])
  end


  def test_data_response_ignore_headers_all
    raw = File.read "test/mocks/200_response.json"
    data = JSON.parse raw.split("\r\n\r\n", 2)[1]

    assert_equal [data],
      @ddiff.data_response(@ddiff.resp1, :ignore_headers => true)
  end


  def test_data_response_ignore_headers_single
    raw = File.read "test/mocks/200_response.json"
    data = JSON.parse raw.split("\r\n\r\n", 2)[1]
    head = @ddiff.resp1.to_hash

    head.delete 'date'

    assert_equal [head, data],
      @ddiff.data_response(@ddiff.resp1, :ignore_headers => :date)
  end


  def test_data_response_ignore_headers_multiple
    raw = File.read "test/mocks/200_response.json"
    data = JSON.parse raw.split("\r\n\r\n", 2)[1]
    head = @ddiff.resp1.to_hash

    head.delete 'date'
    head.delete 'content-type'

    assert_equal [head, data],
      @ddiff.data_response(@ddiff.resp1,
        :ignore_headers => [:date, 'Content-Type'])
  end


  def test_data_response_json
    raw = File.read "test/mocks/200_response.json"
    data = JSON.parse raw.split("\r\n\r\n", 2)[1]
    head = @ddiff.resp1.to_hash

    assert_equal [head, data], @ddiff.data_response(@ddiff.resp1)

    head.delete 'content-type'

    assert_equal [head, data],
      @ddiff.data_response(@ddiff.resp2, :ignore_headers => "Content-Type")
  end


  def test_data_response_xml
    raw = File.read "test/mocks/200_response.xml"
    data = Kronk::XMLParser.parse raw.split("\r\n\r\n", 2)[1]

    assert_equal [@ddiff.resp2.to_hash, data],
                  @ddiff.data_response(@ddiff.resp2)
  end


  def test_data_response_plist
    @ddiff = Kronk::ResponseDiff.retrieve_new "test/mocks/200_response.json",
                                              "test/mocks/200_response.plist"

    raw = File.read "test/mocks/200_response.plist"
    data = Kronk::PlistParser.parse raw.split("\r\n\r\n", 2)[1]
    head = @ddiff.resp2.to_hash

    assert_equal [head, data], @ddiff.data_response(@ddiff.resp2)

    head.delete 'content-type'

    assert_equal [head, data],
      @ddiff.data_response(@ddiff.resp1, :ignore_headers => "Content-Type")
  end


  def test_data_response_missing_parser
    assert_raises Kronk::ResponseDiff::MissingParser do
      @rdiff.data_response @rdiff.resp1
    end
  end


  def test_data_response_bad_parser
    assert_raises JSON::ParserError do
      @ddiff.data_response @ddiff.resp2, :parser => JSON
    end
  end


  def test_data_response_header_keep_all
    expected = {
      "expires"         =>["-1"],
      "content-type"    =>["text/html; charset=ISO-8859-1"],
      "date"            =>["Fri, 26 Nov 2010 16:16:08 GMT"],
      "server"          =>["gws"],
      "x-xss-protection"=>["1; mode=block"],
      "set-cookie"      =>
        ["PREF=ID=99d644506f26d85e:FF=0:TM=1290788168:LM=1290788168:S=VSMemgJxlmlToFA3; expires=Sun, 25-Nov-2012 16:16:08 GMT; path=/; domain=.google.com", "NID=41=CcmNDE4SfDu5cdTOYVkrCVjlrGO-oVbdo1awh_p8auk2gI4uaX1vNznO0QN8nZH4Mh9WprRy3yI2yd_Fr1WaXVru6Xq3adlSLGUTIRW8SzX58An2nH3D2PhAY5JfcJrl; expires=Sat, 28-May-2011 16:16:08 GMT; path=/; domain=.google.com; HttpOnly"],
      "cache-control"   =>["private, max-age=0"],
      "transfer-encoding"=>["chunked"]
    }

    assert_equal expected, @rdiff.data_response_header(@rdiff.resp1)
    assert_equal expected, @rdiff.data_response_header(@rdiff.resp1, false)
  end


  def test_data_response_header_delete_one
    expected = {
      "expires"         =>["-1"],
      "content-type"    =>["text/html; charset=ISO-8859-1"],
      "server"          =>["gws"],
      "x-xss-protection"=>["1; mode=block"],
      "set-cookie"      =>
        ["PREF=ID=99d644506f26d85e:FF=0:TM=1290788168:LM=1290788168:S=VSMemgJxlmlToFA3; expires=Sun, 25-Nov-2012 16:16:08 GMT; path=/; domain=.google.com", "NID=41=CcmNDE4SfDu5cdTOYVkrCVjlrGO-oVbdo1awh_p8auk2gI4uaX1vNznO0QN8nZH4Mh9WprRy3yI2yd_Fr1WaXVru6Xq3adlSLGUTIRW8SzX58An2nH3D2PhAY5JfcJrl; expires=Sat, 28-May-2011 16:16:08 GMT; path=/; domain=.google.com; HttpOnly"],
      "cache-control"   =>["private, max-age=0"],
      "transfer-encoding"=>["chunked"]
    }

    assert_equal expected, @rdiff.data_response_header(@rdiff.resp1, :Date)
  end


  def test_data_response_header_delete_many
    expected = {
      "content-type"    =>["text/html; charset=ISO-8859-1"],
      "x-xss-protection"=>["1; mode=block"],
      "set-cookie"      =>
        ["PREF=ID=99d644506f26d85e:FF=0:TM=1290788168:LM=1290788168:S=VSMemgJxlmlToFA3; expires=Sun, 25-Nov-2012 16:16:08 GMT; path=/; domain=.google.com", "NID=41=CcmNDE4SfDu5cdTOYVkrCVjlrGO-oVbdo1awh_p8auk2gI4uaX1vNznO0QN8nZH4Mh9WprRy3yI2yd_Fr1WaXVru6Xq3adlSLGUTIRW8SzX58An2nH3D2PhAY5JfcJrl; expires=Sat, 28-May-2011 16:16:08 GMT; path=/; domain=.google.com; HttpOnly"],
      "cache-control"   =>["private, max-age=0"],
      "transfer-encoding"=>["chunked"]
    }

    assert_equal expected,
      @rdiff.data_response_header(@rdiff.resp1, [:Date, 'expires', "Server"])
  end


  def test_data_response_header_delete_all
    assert_nil @rdiff.data_response_header(@rdiff.resp1, true)
  end


  def test_delete_data_points_all
    assert_nil @rdiff.delete_data_points mock_data, true
  end


  def test_delete_data_points_single
    data = @rdiff.delete_data_points mock_data, "subs/1"

    expected = mock_data
    expected['subs'].delete_at 1

    assert_equal expected, data
  end


  def test_delete_data_points_single_wildcard
    data = @rdiff.delete_data_points mock_data, "root/*/tests"

    expected = mock_data
    expected['root'][3].delete :tests

    assert_equal expected, data
  end


  def test_delete_data_points_single_wildcard_qmark
    data = @rdiff.delete_data_points mock_data, "subs/?"

    expected = mock_data
    expected['subs'].clear

    assert_equal expected, data
  end


  def test_delete_data_points_recursive_wildcard
    data = @rdiff.delete_data_points mock_data, "**/test?"

    expected = mock_data
    expected['root'][3].delete :tests
    expected['root'][3].delete 'test'
    expected.delete "tests"

    assert_equal expected, data
  end


  def test_delete_data_points_recursive_wildcard_value
    data = @rdiff.delete_data_points mock_data, "**=A?"

    expected = mock_data
    expected['root'][1].clear

    assert_equal expected, data
  end


  def test_ordered_data_string
    expected = <<STR
{
"acks"  => [
 [
  56,
  78,
  ],
 [
  "12",
  "34",
  ],
 ],
"root"  => [
 [
  "B1",
  "B2",
  ],
 [
  "A1",
  "A2",
  ],
 [
  "C1",
  "C2",
  [
   "C3a",
   "C3b",
   ],
  ],
 {
  "test" => [
   [
    "D1a\\nContent goes here",
    "D1b",
    ],
   "D2",
   ],
  :tests => [
   "D3a",
   "D3b",
   ]
  },
 ],
"subs"  => [
 "a",
 "b",
 ],
"tests" => {
 "test" => [
  [
   1,
   2,
   ],
  2.123,
  ],
 :foo   => :bar
 }
}
STR

    assert_equal expected.strip, @rdiff.ordered_data_string(mock_data)
  end


  def test_raw_diff
    rdiff = Kronk::ResponseDiff.retrieve_new "test/mocks/301_response.txt",
                                             "test/mocks/302_response.txt"

    expected = [
      [["HTTP/1.1 301 Moved Permanently", "Location: http://www.google.com/"],
       ["HTTP/1.1 302 Found", "Location: http://igoogle.com/"]],
      "Content-Type: text/html; charset=UTF-8",
      "Date: Fri, 26 Nov 2010 16:14:45 GMT",
      "Expires: Sun, 26 Dec 2010 16:14:45 GMT",
      "Cache-Control: public, max-age=2592000",
      "Server: gws",
      [["Content-Length: 219"], ["Content-Length: 260"]],
      "X-XSS-Protection: 1; mode=block",
      "",
      "<HTML><HEAD><meta http-equiv=\"content-type\" content=\"text/html;charset=utf-8\">",
      [["<TITLE>301 Moved</TITLE></HEAD><BODY>", "<H1>301 Moved</H1>"],
       ["<TITLE>302 Found</TITLE></HEAD><BODY>", "<H1>302 Found</H1>"]],
      "The document has moved",
      "<A HREF=\"http://www.google.com/\">here</A>.",
      [[], ["<A HREF=\"http://igoogle.com/\">here</A>."]],
      "</BODY></HTML>"
    ]

    assert_equal expected, rdiff.raw_diff.to_a
  end


  def test_raw_response
    assert_equal mock_200_response, @rdiff.raw_response(@rdiff.resp1)
  end


  def test_raw_response_no_headers
    body = mock_200_response.split("\r\n\r\n", 2)[1]
    assert_equal body, @rdiff.raw_response(@rdiff.resp1, true)
  end


  def test_raw_response_ignore_one_header
    expected = mock_200_response.gsub!(%r{^Content-Type: [^\n]*$}im, '')
    returned = @rdiff.raw_response @rdiff.resp1, 'Content-Type'

    assert_equal expected, returned
    assert !(returned =~ /^Content-Type: /)
  end


  def test_raw_response_ignore_multiple_headers
    expected = mock_200_response.gsub!(%r{^(Content-Type|Date): [^\n]*$}im, '')
    returned = @rdiff.raw_response @rdiff.resp1, ['Content-Type', 'Date']

    assert_equal expected, returned
    assert !(returned =~ /^Content-Type: /)
    assert !(returned =~ /^Date: /)
  end


  def test_raw_response_header
    headers = @rdiff.raw_response_header @rdiff.resp1
    assert_equal mock_200_response.split("\r\n\r\n")[0], headers

    headers = @rdiff.raw_response_header @rdiff.resp1, false
    assert_equal mock_200_response.split("\r\n\r\n")[0], headers
  end


  def test_raw_response_header_ary_excludes
    headers  = @rdiff.raw_response_header @rdiff.resp1, "Content-Type"
    expected = mock_200_response.split("\r\n\r\n")[0]
    lines    = expected.split("\r\n").length
    expected.gsub!(%r{^Content-Type: [^\n]*$}im, '')

    assert_equal((lines - 1), headers.split("\r\n").length)
    assert_equal expected, headers
    assert headers =~ /^Server:/
    assert headers =~ /^Transfer-Encoding:/
  end


  def test_nil_raw_response_header
    headers = @rdiff.raw_response_header @rdiff.resp1, true
    assert_nil headers
  end
end
