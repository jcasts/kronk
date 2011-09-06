require 'test/test_helper'

class TestDiff < Test::Unit::TestCase

  def setup
    @diff = Kronk::Diff.new mock_302_response, mock_301_response
  end


  def test_find_common
    arr1 = [1,2,3,4,5,6,7,8,9,0]
    arr2 = [2,3,1,4,7,8,9,0,5,6]

    assert_equal [[2, 1, 0], [1, 3, 3], [4, 6, 4]],
                @diff.find_common(arr1, arr2).compact
  end


  def test_find_common_prelast_only_diff
    arr1 = [1,2,3,4,5,6,0]
    arr2 = [1,2,3,4,5,0]

    assert_equal [[5,0,0],[1,6,5]],
                @diff.find_common(arr1, arr2).compact
  end


  def test_find_common_many
    arr1 = [1,2,3,4,5,6,7,8,9,0,7,8,9,1,2,0,4,4]
    arr2 = [2,3,1,4,7,8,9,0,5,6,1,7,8,0,0,9,1,2,4,4]

    assert_equal [[2,1,0],[1,3,3],[4,6,4],[2,10,11],[3,12,15],[2,16,18]],
                 @diff.find_common(arr1, arr2).compact
  end


  def test_new_from_data
    other_data = {:foo => :bar}

    diff = Kronk::Diff.new_from_data mock_data, other_data

    assert_equal Kronk::Diff.ordered_data_string(mock_data), diff.str1
    assert_equal Kronk::Diff.ordered_data_string(other_data), diff.str2
  end


  def test_ordered_data_string_json
    expected = <<STR
{
 "acks": [
  [
   56,
   78
  ],
  [
   "12",
   "34"
  ]
 ],
 "root": [
  [
   "B1",
   "B2"
  ],
  [
   "A1",
   "A2"
  ],
  [
   "C1",
   "C2",
   [
    "C3a",
    "C3b"
   ]
  ],
  {
   ":tests": [
    "D3a",
    "D3b"
   ],
   "test": [
    [
     "D1a\\nContent goes here",
     "D1b"
    ],
    "D2"
   ]
  }
 ],
 "subs": [
  "a",
  "b"
 ],
 "tests": {
  ":foo": ":bar",
  "test": [
   [
    1,
    2
   ],
   2.123
  ]
 }
}
STR

    assert_equal expected.strip, Kronk::Diff.ordered_data_string(mock_data)
  end


  def test_ordered_data_string_struct_json
    expected = <<STR
{
 "acks": [
  [
   "Fixnum",
   "Fixnum"
  ],
  [
   "String",
   "String"
  ]
 ],
 "root": [
  [
   "String",
   "String"
  ],
  [
   "String",
   "String"
  ],
  [
   "String",
   "String",
   [
    "String",
    "String"
   ]
  ],
  {
   ":tests": [
    "String",
    "String"
   ],
   "test": [
    [
     "String",
     "String"
    ],
    "String"
   ]
  }
 ],
 "subs": [
  "String",
  "String"
 ],
 "tests": {
  ":foo": "Symbol",
  "test": [
   [
    "Fixnum",
    "Fixnum"
   ],
   "Float"
  ]
 }
}
STR

    assert_equal expected.strip,
                  Kronk::Diff.ordered_data_string(mock_data, true)
  end

  def test_ordered_data_string_json
    expected = <<STR
{
 "acks": [
  [
   56,
   78
  ],
  [
   "12",
   "34"
  ]
 ],
 "root": [
  [
   "B1",
   "B2"
  ],
  [
   "A1",
   "A2"
  ],
  [
   "C1",
   "C2",
   [
    "C3a",
    "C3b"
   ]
  ],
  {
   ":tests": [
    "D3a",
    "D3b"
   ],
   "test": [
    [
     "D1a\\nContent goes here",
     "D1b"
    ],
    "D2"
   ]
  }
 ],
 "subs": [
  "a",
  "b"
 ],
 "tests": {
  ":foo": ":bar",
  "test": [
   [
    1,
    2
   ],
   2.123
  ]
 }
}
STR

    assert_equal expected.strip, Kronk::Diff.ordered_data_string(mock_data)
  end


  def test_ordered_data_string_ruby_paths
    with_config :render_lang => 'ruby', :render_paths => true do
      expected = <<STR
{
 "/acks/0/0" => 56,
 "/acks/0/1" => 78,
 "/acks/1/0" => "12",
 "/acks/1/1" => "34",
 "/root/0/0" => "B1",
 "/root/0/1" => "B2",
 "/root/1/0" => "A1",
 "/root/1/1" => "A2",
 "/root/2/0" => "C1",
 "/root/2/1" => "C2",
 "/root/2/2/0" => "C3a",
 "/root/2/2/1" => "C3b",
 "/root/3/test/0/0" => "D1a\\nContent goes here",
 "/root/3/test/0/1" => "D1b",
 "/root/3/test/1" => "D2",
 "/root/3/tests/0" => "D3a",
 "/root/3/tests/1" => "D3b",
 "/subs/0" => "a",
 "/subs/1" => "b",
 "/tests/foo" => :bar,
 "/tests/test/0/0" => 1,
 "/tests/test/0/1" => 2,
 "/tests/test/1" => 2.123
}
STR

      assert_equal expected.strip, Kronk::Diff.ordered_data_string(mock_data)
    end
  end


  def test_ordered_data_string_struct_ruby
    with_config :render_lang => 'ruby' do
      expected = <<STR
{
 "acks" => [
  [
   Fixnum,
   Fixnum
  ],
  [
   String,
   String
  ]
 ],
 "root" => [
  [
   String,
   String
  ],
  [
   String,
   String
  ],
  [
   String,
   String,
   [
    String,
    String
   ]
  ],
  {
   :tests => [
    String,
    String
   ],
   "test" => [
    [
     String,
     String
    ],
    String
   ]
  }
 ],
 "subs" => [
  String,
  String
 ],
 "tests" => {
  :foo => Symbol,
  "test" => [
   [
    Fixnum,
    Fixnum
   ],
   Float
  ]
 }
}
STR

      assert_equal expected.strip,
                    Kronk::Diff.ordered_data_string(mock_data, true)
    end
  end


  def test_create_diff_inverted
    @diff = Kronk::Diff.new mock_301_response, mock_302_response
    assert_equal diff_301_302, @diff.create_diff
  end


  def test_create_diff
    assert_equal diff_302_301, @diff.create_diff
    assert_equal @diff.to_a, @diff.create_diff
    assert_equal @diff.to_a, @diff.diff_array
  end


  def test_create_diff_no_match
    str1 = "this is str1\nthat shouldn't\nmatch\nany of\nthe\nlines"
    str2 = "this is str2\nwhich should\nalso not match\nany\nof the\nstr1 lines"

    diff = Kronk::Diff.new str1, str2
    assert_equal [[str1.split("\n"), str2.split("\n")]], diff.create_diff
  end


  def test_create_diff_all_match
    str1 = "this is str\nthat should\nmatch\nall of\nthe\nlines"
    str2 = "this is str\nthat should\nmatch\nall of\nthe\nlines"

    diff = Kronk::Diff.new str1, str2
    assert_equal str1.split("\n"), diff.create_diff
  end


  def test_create_diff_all_added
    str1 = "this is str\nthat should\nmatch\nall of\nthe\nlines"
    str2 = "this is str\nmore stuff\nthat should\nmatch\nall of\nthe\nold lines"

    expected = [
      "this is str",
      [[], ["more stuff"]],
      "that should",
      "match",
      "all of",
      "the",
      [["lines"], ["old lines"]]
    ]

    diff = Kronk::Diff.new str1, str2
    assert_equal expected, diff.create_diff
  end


  def test_create_diff_all_removed
    str1 = "this is str\nmore stuff\nthat should\nmatch\nall of\nthe\nold lines"
    str2 = "this is str\nthat should\nmatch\nall of\nthe\nlines"

    expected = [
      "this is str",
      [["more stuff"], []],
      "that should",
      "match",
      "all of",
      "the",
      [["old lines"], ["lines"]]
    ]

    diff = Kronk::Diff.new str1, str2
    assert_equal expected, diff.create_diff
  end


  def test_create_diff_multi_removed
    str1 = "this str\nmore stuff\nagain\nshould\nmatch\nall of\nthe\nold lines"
    str2 = "this str\nthat should\nmatch\nall of\nthe\nlines"

    expected = [
      "this str",
      [["more stuff", "again", "should"], ["that should"]],
      "match",
      "all of",
      "the",
      [["old lines"], ["lines"]]
    ]

    diff = Kronk::Diff.new str1, str2
    assert_equal expected, diff.create_diff
  end


  def test_create_diff_long_end_diff
    str1 = "this str\nis done"
    str2 = "this str\nthat should\nmatch\nall of\nthe\nlines"

    expected = [
      "this str",
      [["is done"], ["that should", "match", "all of", "the", "lines"]],
    ]

    diff = Kronk::Diff.new str1, str2
    assert_equal expected, diff.create_diff
  end


  def test_create_diff_long_end_diff_inverted
    str1 = "this str\nthat should\nmatch\nall of\nthe\nlines"
    str2 = "this str\nis done"

    expected = [
      "this str",
      [["that should", "match", "all of", "the", "lines"], ["is done"]],
    ]

    diff = Kronk::Diff.new str1, str2
    assert_equal expected, diff.create_diff
  end


  def test_create_diff_long
    str1 = "this str"
    str2 = "this str\nthat should\nmatch\nall of\nthe\nlines"

    expected = [
      "this str",
      [[], ["that should", "match", "all of", "the", "lines"]],
    ]

    diff = Kronk::Diff.new str1, str2
    assert_equal expected, diff.create_diff
  end


  def test_create_diff_long_inverted
    str1 = "this str\nthat should\nmatch\nall of\nthe\nlines"
    str2 = "this str"

    expected = [
      "this str",
      [["that should", "match", "all of", "the", "lines"], []],
    ]

    diff = Kronk::Diff.new str1, str2
    assert_equal expected, diff.create_diff
  end


  def test_create_diff_smallest_match
    str1 = "line1\nline right\nline4\nline4\nline5\nline6\nline2\nline7"
    str2 = "line1\nline left\nline2\nline3\nline4\nline5"

    expected = [
      "line1",
      [["line right", "line4"], ["line left", "line2", "line3"]],
      "line4",
      "line5",
      [["line6", "line2", "line7"], []]
    ]

    diff = Kronk::Diff.new str1, str2
    assert_equal expected, diff.create_diff
  end


  def test_count
    assert_equal 4, @diff.count
  end


  def test_formatted
    assert_equal diff_302_301_str, @diff.formatted
  end


  def test_formatted_lines
    output = @diff.formatted :show_lines => true
    assert_equal diff_302_301_str_lines, output
  end


  def test_formatted_color
    assert_equal diff_302_301_color,
      @diff.formatted(:formatter => Kronk::Diff::ColorFormat)

    @diff.formatter = Kronk::Diff::ColorFormat
    assert_equal diff_302_301_color, @diff.formatted
  end


  def test_formatted_join_char
    expected = diff_302_301_str.gsub(/\n/, "\r\n")
    assert_equal expected,
      @diff.formatted(
        :formatter => Kronk::Diff::AsciiFormat,
        :join_char => "\r\n")
  end


  def test_formatted_context
    resp1 = Kronk::Response.read_file "test/mocks/200_response_diff.json"
    resp2 = Kronk::Response.read_file "test/mocks/200_response.json"
    @diff = Kronk::Diff.new resp1.stringify, resp2.stringify

    assert_equal diff_json_color,
                 @diff.formatted(:formatter => Kronk::Diff::ColorFormat,
                                 :context   => 3,
                                 :labels    => [resp1.uri, resp2.uri])
  end


  class CustomFormat < Kronk::Diff::AsciiFormat
    def self.added str
      ">>>301>>> #{str}"
    end

    def self.deleted str
      "<<<302<<< #{str}"
    end

    def self.common str
      str.to_s
    end
  end

  def test_formatted_custom
    str_diff = @diff.formatted :formatter => CustomFormat
    expected = diff_302_301_str.gsub(/^\+ /, ">>>301>>> ")
    expected = expected.gsub(/^\- /, "<<<302<<< ")
    expected = expected.gsub(/^\s\s/, "")

    assert_equal expected, str_diff
  end

  private

  def diff_json_color
    (<<-STR
\e[33m--- test/mocks/200_response_diff.json
+++ test/mocks/200_response.json\e[0m
\e[35m@@ -6,7 +6,7 @@\e[0m business/description
     "additional_urls": [
      {
       "destination": "http://example.com",
\e[31m-      "url_click": "http://google.com"\e[0m
\e[32m+      "url_click": "http://example.com"\e[0m
      }
     ],
     "general_info": "<p>A Paint Your Own Pottery Studios..</p>",
\e[35m@@ -15,11 +15,12 @@\e[0m business/description
     "slogan": "<p>Pottery YOU dress up</p>"
    },
    "distance": 0.0,
\e[31m-   "has_detail_page": false,\e[0m
\e[32m+   "has_detail_page": true,\e[0m
    "headings": [
     "Pottery"
    ],
\e[31m-   "id": 1234,\e[0m
\e[32m+   "id": "1234",\e[0m
\e[32m+   "impression_id": "mock_iid",\e[0m
    "improvable": true,
    "latitude": 42.882561,
    "listing_id": "1234",
\e[35m@@ -34,12 +35,12 @@\e[0m business
    "rating_count": 0,
    "red_listing": false,
    "state": "MI",
\e[31m-   "website": "http://google.com",\e[0m
\e[32m+   "website": "http://example.com",\e[0m
    "year_established": "1996",
    "zip": "49418"
   },
\e[31m-  "original": {\e[0m
\e[32m+  "original_request": {\e[0m
    "id": "1234"
   },
\e[31m-  "request_id": "foobar"\e[0m
\e[32m+  "request_id": "mock_rid"\e[0m
  }
    STR
    ).strip
  end


  def diff_302_301
    [[["HTTP/1.1 302 Found", "Location: http://igoogle.com/"],
      ["HTTP/1.1 301 Moved Permanently", "Location: http://www.google.com/"]],
    "Content-Type: text/html; charset=UTF-8",
    "Date: Fri, 26 Nov 2010 16:14:45 GMT",
    "Expires: Sun, 26 Dec 2010 16:14:45 GMT",
    "Cache-Control: public, max-age=2592000",
    "Server: gws",
    [["Content-Length: 260"], ["Content-Length: 219"]],
    "X-XSS-Protection: 1; mode=block",
    "",
    "<HTML><HEAD><meta http-equiv=\"content-type\" content=\"text/html;charset=utf-8\">",
    [["<TITLE>302 Found</TITLE></HEAD><BODY>", "<H1>302 Found</H1>"],
      ["<TITLE>301 Moved</TITLE></HEAD><BODY>", "<H1>301 Moved</H1>"]],
    "The document has moved", "<A HREF=\"http://www.google.com/\">here</A>.",
    [["<A HREF=\"http://igoogle.com/\">here</A>."], []],
    "</BODY></HTML>"]
  end

  def diff_301_302
    [[["HTTP/1.1 301 Moved Permanently", "Location: http://www.google.com/"],
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
    "The document has moved", "<A HREF=\"http://www.google.com/\">here</A>.",
    [[], ["<A HREF=\"http://igoogle.com/\">here</A>."]],
    "</BODY></HTML>"]
  end


  def diff_302_301_str
    str = <<STR
--- left
+++ right
- HTTP/1.1 302 Found
- Location: http://igoogle.com/
+ HTTP/1.1 301 Moved Permanently
+ Location: http://www.google.com/
  Content-Type: text/html; charset=UTF-8
  Date: Fri, 26 Nov 2010 16:14:45 GMT
  Expires: Sun, 26 Dec 2010 16:14:45 GMT
  Cache-Control: public, max-age=2592000
  Server: gws
- Content-Length: 260
+ Content-Length: 219
  X-XSS-Protection: 1; mode=block
  
  <HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
- <TITLE>302 Found</TITLE></HEAD><BODY>
- <H1>302 Found</H1>
+ <TITLE>301 Moved</TITLE></HEAD><BODY>
+ <H1>301 Moved</H1>
  The document has moved
  <A HREF="http://www.google.com/">here</A>.
- <A HREF="http://igoogle.com/">here</A>.
  </BODY></HTML>
STR
    str.strip
  end


  def diff_302_301_str_lines
    str = <<STR
--- left
+++ right
 1|   - HTTP/1.1 302 Found
 2|   - Location: http://igoogle.com/
  | 1 + HTTP/1.1 301 Moved Permanently
  | 2 + Location: http://www.google.com/
 3| 3   Content-Type: text/html; charset=UTF-8
 4| 4   Date: Fri, 26 Nov 2010 16:14:45 GMT
 5| 5   Expires: Sun, 26 Dec 2010 16:14:45 GMT
 6| 6   Cache-Control: public, max-age=2592000
 7| 7   Server: gws
 8|   - Content-Length: 260
  | 8 + Content-Length: 219
 9| 9   X-XSS-Protection: 1; mode=block
10|10   
11|11   <HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
12|   - <TITLE>302 Found</TITLE></HEAD><BODY>
13|   - <H1>302 Found</H1>
  |12 + <TITLE>301 Moved</TITLE></HEAD><BODY>
  |13 + <H1>301 Moved</H1>
14|14   The document has moved
15|15   <A HREF="http://www.google.com/">here</A>.
16|   - <A HREF="http://igoogle.com/">here</A>.
17|16   </BODY></HTML>
STR

    str.rstrip
  end


  def diff_302_301_color
    str = <<STR
\e[33m--- left
+++ right\033[0m
\033[31m- HTTP/1.1 302 Found\033[0m
\033[31m- Location: http://igoogle.com/\033[0m
\033[32m+ HTTP/1.1 301 Moved Permanently\033[0m
\033[32m+ Location: http://www.google.com/\033[0m
  Content-Type: text/html; charset=UTF-8
  Date: Fri, 26 Nov 2010 16:14:45 GMT
  Expires: Sun, 26 Dec 2010 16:14:45 GMT
  Cache-Control: public, max-age=2592000
  Server: gws
\033[31m- Content-Length: 260\033[0m
\033[32m+ Content-Length: 219\033[0m
  X-XSS-Protection: 1; mode=block
  
  <HTML><HEAD><meta http-equiv="content-type" content="text/html;charset=utf-8">
\033[31m- <TITLE>302 Found</TITLE></HEAD><BODY>\033[0m
\033[31m- <H1>302 Found</H1>\033[0m
\033[32m+ <TITLE>301 Moved</TITLE></HEAD><BODY>\033[0m
\033[32m+ <H1>301 Moved</H1>\033[0m
  The document has moved
  <A HREF="http://www.google.com/">here</A>.
\033[31m- <A HREF="http://igoogle.com/">here</A>.\033[0m
  </BODY></HTML>
STR
    str.strip
  end
end
