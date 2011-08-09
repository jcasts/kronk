require 'test/test_helper'

class TestRequestParser < Test::Unit::TestCase

  def test_start_new
    assert Kronk::Player::RequestParser.start_new?("/foobar\r\n")
    assert Kronk::Player::RequestParser.start_new?("GET /foobar\r\n")
    assert !Kronk::Player::RequestParser.start_new?("http://example.com\r\n")
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
