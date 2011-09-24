require 'test/test_helper'

class TestRequestParser < Test::Unit::TestCase

  def test_start_new
    assert Kronk::Player::RequestParser.start_new?("/foobar\r\n")
    assert Kronk::Player::RequestParser.start_new?("GET /foobar\r\n")
    assert Kronk::Player::RequestParser.start_new?("http://example.com\r\n")
    assert Kronk::Player::RequestParser.start_new?("https://example.com\r\n")
    assert Kronk::Player::RequestParser.start_new?("https://foo.com/\r\n")
    assert Kronk::Player::RequestParser.start_new?("/\r\n")
    assert Kronk::Player::RequestParser.start_new?("https://foo.com/bar\r\n")
    assert Kronk::Player::RequestParser.start_new?(
      "10.1.8.10 - - [20/Sep/2011:20:57:54 +0000] \"GET /users/d7399ed0-c5f1-012e-cf4d-00163e2aabff.json HTTP/1.1\" 200 550 \"-\" \"Ruby\" \"-\" 0.009\n")
    assert !Kronk::Player::RequestParser.start_new?("foobar\r\n")
  end


  def test_parse
    expected = {:uri_suffix => "/foobar"}
    assert_equal expected, Kronk::Player::RequestParser.parse("/foobar")

    expected = {:http_method => "GET", :uri_suffix => "/foobar"}
    assert_equal expected, Kronk::Player::RequestParser.parse("GET /foobar")

    expected.merge! :host => "example.com"
    raw = "GET /foobar\r\nHost: example.com"
    assert_equal expected, Kronk::Player::RequestParser.parse(raw)

    expected.merge! :http_method => "POST",
                    :data        => "foo=bar",
                    :headers     => {'Accept' => 'json'}

    raw = "POST /foobar\r\nAccept: json\r\nHost: example.com\r\n\r\nfoo=bar"
    assert_equal expected, Kronk::Player::RequestParser.parse(raw)
  end
end
