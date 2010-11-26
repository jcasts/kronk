require 'test/test_helper'

class TestRequest < Test::Unit::TestCase


  def test_call_post
    expect_request "POST", "http://example.com/request/path?foo=bar",
      :data => {'test' => 'thing'}, :headers => {'X-THING' => 'thing'}

    resp = Kronk::Request.call :post, "http://example.com/request/path?foo=bar",
            :data => 'test=thing', :headers => {'X-THING' => 'thing'}

    assert_equal mock_200_response, resp.raw
  end


  def test_call_get
    expect_request "GET", "http://example.com/request/path?foo=bar"
    resp = Kronk::Request.call :get, "http://example.com/request/path?foo=bar"

    assert_equal mock_200_response, resp.raw
  end


  def test_build_query_hash
    hash = {
      :foo => :bar,
      :a => ['one', 'two'],
      :b => {:b1 => [1,2], :b2 => "test"}
    }

    assert_equal "a[]=one&a[]=two&b[b1][]=1&b[b1][]=2&b[b2]=test&foo=bar",
                  Kronk::Request.build_query(hash)
  end


  def test_build_query_non_hash
    assert_raises ArgumentError do
      Kronk::Request.build_query [1,2,3]
    end

    assert_equal "q[]=1&q[]=2&q[]=3", Kronk::Request.build_query([1,2,3], "q")
    assert_equal "key=val", Kronk::Request.build_query("val", "key")
  end


  private

  def expect_request req_method, url, options={}
    uri  = URI.parse url

    resp = mock 'resp'
    http = mock 'http'
    socket = mock 'socket'

    data   = options[:data]
    data &&= Hash === data ? Kronk::Request.build_query(data) : data.to_s

    socket.expects(:debug_output=)

    http.expects(:send_request).
      with(req_method, uri.request_uri, data, options[:headers]).
      returns resp

    http.expects(:instance_variable_get).with("@socket").returns socket

    Net::HTTP.expects(:start).with(uri.host, uri.port).yields http

    Kronk::Response.expects(:read_raw_from).returns ["", mock_200_response, 0]
  end
end
