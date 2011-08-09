require 'test/test_helper'

class TestInputReader < Test::Unit::TestCase

  def setup
    @input = Kronk::Player::InputReader.new "/path1\n/path2\n/path3\n"
  end


  def test_init
    input = Kronk::Player::InputReader.new "foobar"
    assert_equal StringIO, input.io.class
    assert_equal Kronk::Player::RequestParser, input.parser
    assert_equal [], input.buffer


    File.open("test/mocks/200_response.txt") do |file|
      input = Kronk::Player::InputReader.new file, "mock parser"
      assert_equal file, input.io
      assert_equal "mock parser", input.parser
    end
  end


  def test_get_next
    (1..3).each do |num|
      expected = {
        :headers     => {},
        :http_method => nil,
        :uri_suffix  => "/path#{num}"
      }
      assert_equal expected, @input.get_next
    end

    assert_nil @input.get_next
    assert @input.eof?
  end


  def test_get_next_full_http_request
    expected = {
      :headers => {
        "Accept"     => "*/*",
        "User-Agent" => "Kronk/1.5.0 (http://github.com/yaksnrainbows/kronk)",
        "Authorization" => "Basic Ym9iOmZvb2Jhcg=="
      },
      :http_method => "GET",
      :uri_suffix  => "/path",
      :host        => "example.com:80",
      :data        => ""
    }

    File.open("test/mocks/get_request.txt") do |file|
      @input = Kronk::Player::InputReader.new file

      assert_equal expected, @input.get_next
      assert_nil @input.get_next
      assert @input.eof?
    end
  end


  def test_get_next_multiple_http_requests
    expected = {
      :headers => {
        "Accept"     => "*/*",
        "User-Agent" => "Kronk/1.5.0 (http://github.com/yaksnrainbows/kronk)",
        "Authorization" => "Basic Ym9iOmZvb2Jhcg=="
      },
      :http_method => "GET",
      :uri_suffix  => "/path",
      :host        => "example.com:80",
      :data        => ""
    }

    req_str = File.read("test/mocks/get_request.txt") * 5

    @input = Kronk::Player::InputReader.new req_str

    5.times do
      assert_equal expected, @input.get_next
    end

    assert_nil @input.get_next
    assert @input.eof?
  end


  def test_eof
    assert !@input.eof?

    old_io, @input.io = @input.io, nil
    assert @input.eof?

    @input.io = old_io
    @input.io.close
    assert @input.eof?

    @input.io.reopen
    @input.io.read
    assert @input.io.eof?
    assert @input.eof?

    @input.buffer << "test"
    assert !@input.eof?
  end
end
