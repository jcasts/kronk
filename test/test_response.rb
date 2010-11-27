require 'test/test_helper'

class TestResponse < Test::Unit::TestCase

  def test_read_new
    File.open "test/mocks/200_response.txt", "r" do |file|
      resp = Kronk::Response.read_new file

      assert Net::HTTPResponse === resp
      assert_equal mock_200_response, resp.raw
      assert_equal mock_200_response.split("\r\n\r\n", 2)[0], resp.raw_header
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
end
