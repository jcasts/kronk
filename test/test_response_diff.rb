require 'test/test_helper'

class TestResponseDiff < Test::Unit::TestCase

  def setup
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


  def test_delete_data_points
    
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
