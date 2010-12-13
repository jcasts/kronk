require 'test/test_helper'

class TestRequest < Test::Unit::TestCase

  def test_follow_redirect
    resp = mock "resp"
    resp.expects(:[]).with("Location").returns "http://example.com"

    options = {:follow_redirects => true, :http_method => :get}
    Kronk::Request.expects(:retrieve_uri).with("http://example.com", options)

    Kronk::Request.follow_redirect resp, options
  end


  def test_num_follow_redirect
    resp = mock "resp"
    resp.expects(:[]).with("Location").returns "http://example.com"

    options = {:follow_redirects => 1}
    Kronk::Request.expects(:retrieve_uri).
      with "http://example.com", :follow_redirects => 0, :http_method => :get

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
      with resp, :follow_redirects => true,
      :headers => {'User-Agent' => Kronk::USER_AGENTS['kronk']}

    Kronk::Request.retrieve_uri "http://example.com/request/path?foo=bar",
      :follow_redirects => true
  end


  def test_retrieve_uri_redirect_3_times
    resp = expect_request "POST", "http://example.com/request/path?foo=bar",
              :status => '301', :data => "foo=bar"

    Kronk::Request.expects(:follow_redirect).
      with resp, :follow_redirects => 3, :data => {:foo => "bar"},
      :headers => {'User-Agent' => Kronk::USER_AGENTS['kronk']}

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


  def test_call_cookies
    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").returns "mock_cookie"

    Kronk.cookie_jar.expects(:set_cookies_from_headers).
      with("http://example.com/request/path?foo=bar", {})

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'Cookie' => "mock_cookie", 'User-Agent' => "kronk"}

    resp = Kronk::Request.call :get, "http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"}
  end


  def test_call_no_cookies_found
    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").returns ""

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk"}

    resp = Kronk::Request.call :get, "http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"}
  end


  def test_call_no_cookies
    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").never

    Kronk.cookie_jar.expects(:set_cookies_from_headers).never

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk"}

    resp = Kronk::Request.call :get, "http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"},
            :no_cookies => true
  end


  def test_call_no_cookies_config
    old_config = Kronk.config[:use_cookies]
    Kronk.config[:use_cookies] = false

    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").never

    Kronk.cookie_jar.expects(:set_cookies_from_headers).never

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk"}

    resp = Kronk::Request.call :get, "http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"}

    Kronk.config[:use_cookies] = old_config
  end


  def test_call_no_cookies_config_override
    old_config = Kronk.config[:use_cookies]
    Kronk.config[:use_cookies] = false

    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").returns ""

    Kronk.cookie_jar.expects(:set_cookies_from_headers)

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk"}

    resp = Kronk::Request.call :get, "http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"},
            :no_cookies => false

    Kronk.config[:use_cookies] = old_config
  end


  def test_call_cookies_already_set
    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").never

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk", 'Cookie' => "mock_cookie"}

    resp = Kronk::Request.call :get, "http://example.com/request/path",
            :query => "foo=bar",
            :headers => {'User-Agent' => "kronk", 'Cookie' => "mock_cookie"},
            :no_cookies => true
  end


  def test_call_query
    expect_request "GET", "http://example.com/path?foo=bar"
    Kronk::Request.call :get, "http://example.com/path",
      :query => {:foo => :bar}
  end


  def test_call_query_appended
    expect_request "GET", "http://example.com/path?foo=bar&test=thing"
    Kronk::Request.call :get, "http://example.com/path?foo=bar",
      :query => {:test => :thing}
  end


  def test_call_query_appended_string
    expect_request "GET", "http://example.com/path?foo=bar&test=thing"
    Kronk::Request.call :get, "http://example.com/path?foo=bar",
      :query => "test=thing"
  end


  def test_call_basic_auth
    auth_opts = {:username => "user", :password => "pass"}

    expect_request "GET", "http://example.com" do |http, req, resp|
      req.expects(:basic_auth).with auth_opts[:username], auth_opts[:password]
    end

    resp = Kronk::Request.call :get, "http://example.com", :auth => auth_opts
  end


  def test_call_bad_basic_auth
    auth_opts = {:password => "pass"}

    expect_request "GET", "http://example.com" do |http, req, resp|
      req.expects(:basic_auth).with(auth_opts[:username], auth_opts[:password]).
        never
    end

    resp = Kronk::Request.call :get, "http://example.com", :auth => auth_opts
  end


  def test_call_no_basic_auth
    expect_request "GET", "http://example.com" do |http, req, resp|
      req.expects(:basic_auth).never
    end

    resp = Kronk::Request.call :get, "http://example.com"
  end


  def test_call_ssl
    expect_request "GET", "https://example.com" do |http, req, resp|
      req.expects(:use_ssl=).with true
    end

    resp = Kronk::Request.call :get, "https://example.com"

    assert_equal mock_200_response, resp.raw
  end


  def test_call_no_ssl
    expect_request "GET", "http://example.com" do |http, req, resp|
      req.expects(:use_ssl=).with(true).never
    end

    resp = Kronk::Request.call :get, "http://example.com"

    assert_equal mock_200_response, resp.raw
  end


  def test_call_user_agent_default
    expect_request "GET", "http://example.com",
    :headers => {
      'User-Agent' =>
        "Kronk/#{Kronk::VERSION} (http://github.com/yaksnrainbows/kronk)"
    }

    resp = Kronk::Request.call :get, "http://example.com"
  end


  def test_call_user_agent_alias
    expect_request "GET", "http://example.com",
    :headers => {'User-Agent' => "Mozilla/5.0 (compatible; Konqueror/3; Linux)"}

    resp = Kronk::Request.call :get, "http://example.com",
             :user_agent => 'linux_konqueror'
  end


  def test_call_user_agent_custom
    expect_request "GET", "http://example.com",
    :headers => {'User-Agent' => "custom user agent"}

    resp = Kronk::Request.call :get, "http://example.com",
             :user_agent => 'custom user agent'
  end


  def test_call_user_agent_header_already_set
    expect_request "GET", "http://example.com",
    :headers => {'User-Agent' => "custom user agent"}

    resp = Kronk::Request.call :get, "http://example.com",
             :user_agent => 'mac_safari',
             :headers    => {'User-Agent' => "custom user agent"}
  end


  def test_call_proxy
    proxy = {
      :address  => "proxy.com",
      :username => "john",
      :password => "smith"
    }

    expect_request "GET", "http://example.com"

    Net::HTTP.expects(:Proxy).with("proxy.com", 8080, "john", "smith").
      returns Net::HTTP

    Kronk::Request.call :get, "http://example.com", :proxy => proxy
  end


  def test_call_proxy_string
    proxy = "proxy.com:8888"

    expect_request "GET", "http://example.com"

    Net::HTTP.expects(:Proxy).with("proxy.com", "8888", nil, nil).
      returns Net::HTTP

    Kronk::Request.call :get, "http://example.com", :proxy => proxy
  end


  def test_proxy_nil
    assert_equal Net::HTTP, Kronk::Request.proxy(nil)
  end


  def test_proxy_string
    proxy_class = Kronk::Request.proxy("myproxy.com:80")

    assert_equal "myproxy.com",
      proxy_class.instance_variable_get("@proxy_address")

    assert_equal '80', proxy_class.instance_variable_get("@proxy_port")

    assert_nil proxy_class.instance_variable_get("@proxy_user")
    assert_nil proxy_class.instance_variable_get("@proxy_pass")
  end


  def test_proxy_no_port
    proxy_class = Kronk::Request.proxy("myproxy.com")

    assert_equal "myproxy.com",
      proxy_class.instance_variable_get("@proxy_address")

    assert_equal 8080, proxy_class.instance_variable_get("@proxy_port")

    assert_nil proxy_class.instance_variable_get("@proxy_user")
    assert_nil proxy_class.instance_variable_get("@proxy_pass")
  end


  def test_proxy_hash
    proxy_class = Kronk::Request.proxy "myproxy.com",
                                       :port      => 8080,
                                       :username  => "john",
                                       :password  => "smith"

    assert_equal "myproxy.com",
      proxy_class.instance_variable_get("@proxy_address")

    assert_equal 8080, proxy_class.instance_variable_get("@proxy_port")

    assert_equal "john", proxy_class.instance_variable_get("@proxy_user")
    assert_equal "smith", proxy_class.instance_variable_get("@proxy_pass")
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
    assert_equal [1,2,3].to_s, Kronk::Request.build_query([1,2,3])

    assert_equal "q[]=1&q[]=2&q[]=3", Kronk::Request.build_query([1,2,3], "q")
    assert_equal "key=val", Kronk::Request.build_query("val", "key")
  end


  def test_vanilla_request
    req = Kronk::Request::VanillaRequest.new :my_http_method,
            "some/path", 'User-Agent' => 'vanilla kronk'

    assert Net::HTTPRequest === req
    assert_equal "MY_HTTP_METHOD", req.class::METHOD
    assert req.class::REQUEST_HAS_BODY
    assert req.class::RESPONSE_HAS_BODY

    assert_equal "some/path", req.path
    assert_equal "vanilla kronk", req['User-Agent']
  end


  private

  def expect_request req_method, url, options={}
    uri  = URI.parse url

    resp = mock 'resp'
    resp.stubs(:code).returns(options[:status] || '200')
    resp.stubs(:to_hash).returns Hash.new

    http   = mock 'http'
    socket = mock 'socket'
    req    = mock 'req'

    data   = options[:data]
    data &&= Hash === data ? Kronk::Request.build_query(data) : data.to_s

    headers = options[:headers] || Hash.new
    headers['User-Agent'] ||= Kronk.config[:user_agents]['kronk']

    socket.expects(:debug_output=)

    Kronk::Request::VanillaRequest.expects(:new).
      with(req_method, uri.request_uri, headers).returns req

    http.expects(:request).with(req, data).returns resp

    http.expects(:instance_variable_get).with("@socket").returns socket

    Net::HTTP.expects(:new).with(uri.host, uri.port).returns req
    req.expects(:start).yields(http).returns resp

    Kronk::Response.expects(:read_raw_from).returns ["", mock_200_response, 0]

    yield http, req, resp if block_given?
    resp
  end
end
