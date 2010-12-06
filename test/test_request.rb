require 'test/test_helper'

class TestRequest < Test::Unit::TestCase

  def test_follow_redirect
    resp = mock "resp"
    resp.expects(:[]).with("Location").returns "http://example.com"

    options = {:follow_redirects => true}
    Kronk::Request.expects(:retrieve_uri).with("http://example.com", options)

    Kronk::Request.follow_redirect resp, options
  end


  def test_num_follow_redirect
    resp = mock "resp"
    resp.expects(:[]).with("Location").returns "http://example.com"

    options = {:follow_redirects => 1}
    Kronk::Request.expects(:retrieve_uri).
      with "http://example.com", :follow_redirects => 0

    Kronk::Request.follow_redirect resp, options
  end


  def test_follow_redirect?
    resp = mock "resp"
    resp.expects(:code).returns "300"

    assert Kronk::Request.follow_redirect?(resp, true)

    resp = mock "resp"
    resp.expects(:code).returns "300"

    assert Kronk::Request.follow_redirect?(resp, 1)
  end


  def test_dont_follow_redirect?
    resp = mock "resp"
    resp.expects(:code).returns "300"

    assert !Kronk::Request.follow_redirect?(resp, false)

    resp = mock "resp"
    resp.expects(:code).returns "300"

    assert !Kronk::Request.follow_redirect?(resp, 0)

    resp = mock "resp"
    resp.expects(:code).returns "200"

    assert !Kronk::Request.follow_redirect?(resp, true)
  end


  def test_retrieve_live
    query   = "http://example.com"
    options = {:foo => "bar"}
    Kronk::Request.expects(:retrieve_uri).with query, options

    Kronk::Request.retrieve query, options
  end


  def test_retrieve_cached
    query   = "path/to/file.txt"
    options = {:foo => "bar"}
    Kronk::Request.expects(:retrieve_file).with query, options

    Kronk::Request.retrieve query, options
  end


  def test_retrieve_file
    resp = Kronk::Request.retrieve_file "test/mocks/200_response.txt"
    assert_equal mock_200_response, resp.raw
    assert_equal "200", resp.code
  end


  def test_retrieve_file_cache
    File.expects(:open).with(Kronk::DEFAULT_CACHE_FILE, "r").
      yields StringIO.new(mock_200_response)

    resp = Kronk::Request.retrieve_file :cache
    assert_equal mock_200_response, resp.raw
    assert_equal "200", resp.code
  end


  def test_retrieve_file_redirect
    resp2 = Kronk::Request.retrieve_file "test/mocks/200_response.txt"
    Kronk::Request.expects(:follow_redirect).returns resp2

    resp = Kronk::Request.retrieve_file "test/mocks/301_response.txt",
            :follow_redirects => true

    assert_equal mock_200_response, resp.raw
    assert_equal "200", resp.code
  end


  def test_retrieve_uri
    expect_request "GET", "http://example.com/request/path?foo=bar"
    Kronk::Request.retrieve_uri "http://example.com/request/path?foo=bar"
  end


  def test_retrieve_uri_redirect
    resp = expect_request "GET", "http://example.com/request/path?foo=bar",
            :status => '301'

    Kronk::Request.expects(:follow_redirect).
      with resp, :follow_redirects => true

    Kronk::Request.retrieve_uri "http://example.com/request/path?foo=bar",
      :follow_redirects => true
  end


  def test_retrieve_uri_redirect_3_times
    resp = expect_request "POST", "http://example.com/request/path?foo=bar",
              :status => '301', :data => "foo=bar"

    Kronk::Request.expects(:follow_redirect).
      with resp, :follow_redirects => 3, :data => {:foo => "bar"}

    Kronk::Request.retrieve_uri "http://example.com/request/path?foo=bar",
      :follow_redirects => 3, :data => {:foo => "bar"}
  end


  def test_retrieve_uri_redirect_none
    expect_request "GET", "http://example.com/request/path?foo=bar",
      :status => 301

    Kronk::Request.expects(:follow_redirect).never

    Kronk::Request.retrieve_uri "http://example.com/request/path?foo=bar"
  end

  def test_retrieve_uri_post
    expect_request "POST", "http://example.com/request/path?foo=bar",
      :data => 'test=thing', :headers => {'X-THING' => 'thing'}

    Kronk::Request.retrieve_uri "http://example.com/request/path?foo=bar",
      :http_method => :post,
      :data => {:test => "thing"},
      :headers => {'X-THING' => 'thing'}
  end


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
    resp.stubs(:code).returns(options[:status] || '200')

    http = mock 'http'
    socket = mock 'socket'

    data   = options[:data]
    data &&= Hash === data ? Kronk::Request.build_query(data) : data.to_s

    socket.expects(:debug_output=)

    http.expects(:send_request).
      with(req_method, uri.request_uri, data, options[:headers]).
      returns resp

    http.expects(:instance_variable_get).with("@socket").returns socket

    Net::HTTP.expects(:start).with(uri.host, uri.port).yields(http).returns resp

    Kronk::Response.expects(:read_raw_from).returns ["", mock_200_response, 0]

    resp
  end
end
