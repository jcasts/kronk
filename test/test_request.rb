require 'test/test_helper'

class TestRequest < Test::Unit::TestCase

  def test_parse
    raw = "POST /foobar\r\nAccept: json\r\nHost: example.com\r\n\r\nfoo=bar"
    req = Kronk::Request.parse(raw)

    assert_equal Kronk::Request, req.class
    assert_equal URI.parse("http://example.com/foobar"), req.uri
    assert_equal "json", req.headers['Accept']
    assert_equal "foo=bar", req.body
  end


  def test_parse_url
    raw = "https://example.com/foobar?foo=bar"
    req = Kronk::Request.parse(raw)

    assert_equal Kronk::Request, req.class
    assert_equal URI.parse("https://example.com/foobar?foo=bar"), req.uri
  end


  def test_parse_url_path
    raw = "/foobar?foo=bar"
    req = Kronk::Request.parse(raw)

    assert_equal Kronk::Request, req.class
    assert_equal URI.parse("http://localhost:3000/foobar?foo=bar"), req.uri
  end


  def test_parse_invalid
    assert_raises Kronk::Request::ParseError do
      Kronk::Request.parse "thing\nfoo\n"
    end
    assert_raises Kronk::Request::ParseError do
      Kronk::Request.parse ""
    end
  end


  def test_parse_to_hash
    expected = {:uri_suffix => "/foobar"}
    assert_equal expected, Kronk::Request.parse_to_hash("/foobar")

    expected = {:http_method => "GET", :uri_suffix => "/foobar"}
    assert_equal expected, Kronk::Request.parse_to_hash("GET /foobar")

    expected.merge! :host => "example.com"
    raw = "GET /foobar\r\nHost: example.com"
    assert_equal expected, Kronk::Request.parse_to_hash(raw)

    expected.merge! :http_method => "POST",
                    :data        => "foo=bar",
                    :headers     => {'Accept' => 'json'}

    raw = "POST /foobar\r\nAccept: json\r\nHost: example.com\r\n\r\nfoo=bar"
    assert_equal expected, Kronk::Request.parse_to_hash(raw)
  end


  def test_parse_to_hash_url
    expected = {:host => "http://example.com", :uri_suffix => "/foobar?foo=bar"}
    assert_equal expected,
      Kronk::Request.parse_to_hash("http://example.com/foobar?foo=bar")
  end


  def test_parse_to_hash_invalid
    assert_nil Kronk::Request.parse_to_hash("thing\nfoo\n")
    assert_nil Kronk::Request.parse_to_hash("")
  end


  def test_retrieve_post
    expect_request "POST", "http://example.com/request/path?foo=bar",
      :data => {'test' => 'thing'}, :headers => {'X-THING' => 'thing'}

    resp = Kronk::Request.new("http://example.com/request/path?foo=bar",
            :data => 'test=thing', :headers => {'X-THING' => 'thing'},
            :http_method => :post).retrieve

    assert_equal mock_200_response, resp.raw
  end


  def test_build_uri
    uri = Kronk::Request.build_uri "https://example.com"
    assert_equal URI.parse("https://example.com"), uri
  end


  def test_build_uri_string
    uri = Kronk::Request.build_uri "example.com"
    assert_equal "http://example.com", uri.to_s
  end


  def test_build_uri_localhost
    uri = Kronk::Request.build_uri "/path/to/resource"
    assert_equal "http://localhost:3000/path/to/resource", uri.to_s
  end


  def test_build_uri_query_hash
    query = {'a' => '1', 'b' => '2'}
    uri   = Kronk::Request.build_uri "example.com/path", :query => query

    assert_equal query, Kronk::Request.parse_nested_query(uri.query)
  end


  def test_build_uri_query_hash_str
    query = {'a' => '1', 'b' => '2'}
    uri   = Kronk::Request.build_uri "example.com/path?c=3", :query => query

    assert_equal({'a' => '1', 'b' => '2', 'c' => '3'},
      Kronk::Request.parse_nested_query(uri.query))
  end


  def test_build_uri_suffix
    uri = Kronk::Request.build_uri "http://example.com/path",
             :uri_suffix => "/to/resource"

    assert_equal "http://example.com/path/to/resource", uri.to_s
  end


  def test_build_uri_from_uri
    query = {'a' => '1', 'b' => '2'}
    uri   = Kronk::Request.build_uri URI.parse("http://example.com/path"),
              :query => query, :uri_suffix => "/to/resource"

    assert_equal "example.com",       uri.host
    assert_equal "/path/to/resource", uri.path
    assert_equal query, Kronk::Request.parse_nested_query(uri.query)
  end


  def test_retrieve_get
    expect_request "GET", "http://example.com/request/path?foo=bar"
    resp =
      Kronk::Request.new("http://example.com/request/path?foo=bar").retrieve

    assert_equal mock_200_response, resp.raw
  end


  def test_retrieve_cookies
    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").returns "mock_cookie"

    Kronk.cookie_jar.expects(:set_cookies_from_headers).
      with("http://example.com/request/path?foo=bar", {})

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'Cookie' => "mock_cookie", 'User-Agent' => "kronk"}

    resp = Kronk::Request.new("http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"}).retrieve
  end


  def test_retrieve_no_cookies_found
    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").returns ""

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk"}

    resp = Kronk::Request.new("http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"}).retrieve
  end


  def test_retrieve_no_cookies
    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").never

    Kronk.cookie_jar.expects(:set_cookies_from_headers).never

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk"}

    resp = Kronk::Request.new("http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"},
            :no_cookies => true).retrieve
  end


  def test_retrieve_no_cookies_config
    old_config = Kronk.config[:use_cookies]
    Kronk.config[:use_cookies] = false

    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").never

    Kronk.cookie_jar.expects(:set_cookies_from_headers).never

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk"}

    resp = Kronk::Request.new("http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"}).retrieve

    Kronk.config[:use_cookies] = old_config
  end


  def test_retrieve_no_cookies_config_override
    old_config = Kronk.config[:use_cookies]
    Kronk.config[:use_cookies] = false

    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").returns ""

    Kronk.cookie_jar.expects(:set_cookies_from_headers)

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk"}

    resp = Kronk::Request.new("http://example.com/request/path",
            :query => "foo=bar", :headers => {'User-Agent' => "kronk"},
            :no_cookies => false).retrieve

    Kronk.config[:use_cookies] = old_config
  end


  def test_retrieve_cookies_already_set
    Kronk.cookie_jar.expects(:get_cookie_header).
      with("http://example.com/request/path?foo=bar").never

    expect_request "GET", "http://example.com/request/path?foo=bar",
      :headers => {'User-Agent' => "kronk"}

    resp = Kronk::Request.new("http://example.com/request/path",
            :query => "foo=bar",
            :headers => {'User-Agent' => "kronk", 'Cookie' => "mock_cookie"},
            :no_cookies => true).retrieve
  end


  def test_retrieve_query
    expect_request "GET", "http://example.com/path?foo=bar"
    Kronk::Request.new("http://example.com/path",
      :query => {:foo => :bar}).retrieve
  end


  def test_retrieve_query_appended
    expect_request "GET", "http://example.com/path?foo=bar&test=thing"
    Kronk::Request.new("http://example.com/path?foo=bar",
      :query => {:test => :thing}).retrieve
  end


  def test_retrieve_query_appended_string
    expect_request "GET", "http://example.com/path?foo=bar&test=thing"
    Kronk::Request.new("http://example.com/path?foo=bar",
      :query => "test=thing").retrieve
  end


  def test_auth_from_headers
    req = Kronk::Request.parse File.read("test/mocks/get_request.txt")
    assert_equal "bob",    req.auth[:username]
    assert_equal "foobar", req.auth[:password]
  end


  def test_auth_from_headers_and_options
    req = Kronk::Request.new "http://example.com/path",
            :headers => {"Authorization" => "Basic Ym9iOmZvb2Jhcg=="},
            :auth    => {:password => "password"}
    assert_equal "bob",      req.auth[:username]
    assert_equal "password", req.auth[:password]
  end


  def test_retrieve_basic_auth
    auth_opts = {:username => "user", :password => "pass"}

    expect_request "GET", "http://example.com" do |http, req, resp|
      req.expects(:basic_auth).with auth_opts[:username], auth_opts[:password]
    end

    resp = Kronk::Request.new("http://example.com", :auth => auth_opts).retrieve
  end


  def test_retrieve_bad_basic_auth
    auth_opts = {:password => "pass"}

    expect_request "GET", "http://example.com" do |http, req, resp|
      req.expects(:basic_auth).with(auth_opts[:username], auth_opts[:password]).
        never
    end

    resp = Kronk::Request.new("http://example.com", :auth => auth_opts).retrieve
  end


  def test_retrieve_no_basic_auth
    expect_request "GET", "http://example.com" do |http, req, resp|
      req.expects(:basic_auth).never
    end

    resp = Kronk::Request.new("http://example.com").retrieve
  end


  def test_retrieve_ssl
    expr = expect_request "GET", "https://example.com" do |http, req, resp|
      req.expects(:use_ssl=).with true
    end

    resp = Kronk::Request.new("https://example.com").retrieve

    assert_equal mock_200_response, resp.raw
  end


  def test_retrieve_no_ssl
    expect_request "GET", "http://example.com" do |http, req, resp|
      req.expects(:use_ssl=).with(true).never
    end

    resp = Kronk::Request.new("http://example.com").retrieve

    assert_equal mock_200_response, resp.raw
  end


  def test_retrieve_user_agent_default
    expect_request "GET", "http://example.com",
    :headers => {
      'User-Agent' =>
        "Kronk/#{Kronk::VERSION} (http://github.com/yaksnrainbows/kronk)"
    }

    resp = Kronk::Request.new("http://example.com").retrieve
  end


  def test_retrieve_user_agent_alias
    expect_request "GET", "http://example.com",
    :headers => {'User-Agent' => "Mozilla/5.0 (compatible; Konqueror/3; Linux)"}

    resp = Kronk::Request.new("http://example.com",
             :user_agent => 'linux_konqueror').retrieve
  end


  def test_retrieve_user_agent_custom
    expect_request "GET", "http://example.com",
    :headers => {'User-Agent' => "custom user agent"}

    resp = Kronk::Request.new("http://example.com",
             :user_agent => 'custom user agent').retrieve
  end


  def test_retrieve_user_agent_header_already_set
    expect_request "GET", "http://example.com",
    :headers => {'User-Agent' => "custom user agent"}

    resp = Kronk::Request.new("http://example.com",
             :user_agent => 'mac_safari',
             :headers    => {'User-Agent' => "custom user agent"}).retrieve
  end


  def test_retrieve_proxy
    proxy = {
      :host     => "proxy.com",
      :username => "john",
      :password => "smith"
    }

    expect_request "GET", "http://example.com"

    Net::HTTP.expects(:Proxy).with("proxy.com", 8080, "john", "smith").
      returns Net::HTTP

    Kronk::Request.new("http://example.com", :proxy => proxy).retrieve
  end


  def test_retrieve_proxy_string
    proxy = "proxy.com:8888"

    expect_request "GET", "http://example.com"

    Net::HTTP.expects(:Proxy).with("proxy.com", "8888", nil, nil).
      returns Net::HTTP

    Kronk::Request.new("http://example.com", :proxy => proxy).retrieve
  end


  def test_proxy_nil
    assert_equal Net::HTTP, Kronk::Request.new("host.com").http_proxy(nil)
  end


  def test_proxy_string
    proxy_class = Kronk::Request.new("host.com").http_proxy("myproxy.com:80")

    assert_equal "myproxy.com",
      proxy_class.instance_variable_get("@proxy_address")

    assert_equal '80', proxy_class.instance_variable_get("@proxy_port")

    assert_nil proxy_class.instance_variable_get("@proxy_user")
    assert_nil proxy_class.instance_variable_get("@proxy_pass")
  end


  def test_proxy_no_port
    proxy_class = Kronk::Request.new("host.com").http_proxy("myproxy.com")

    assert_equal "myproxy.com",
      proxy_class.instance_variable_get("@proxy_address")

    assert_equal 8080, proxy_class.instance_variable_get("@proxy_port")

    assert_nil proxy_class.instance_variable_get("@proxy_user")
    assert_nil proxy_class.instance_variable_get("@proxy_pass")
  end


  def test_proxy_hash
    req = Kronk::Request.new "http://example.com",
            :proxy => { :host     => "myproxy.com",
                        :port     => 8080,
                        :username => "john",
                        :password => "smith" }

    proxy_class = req.http_proxy req.proxy[:host], req.proxy

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
                  Kronk::Request.build_query(hash).split("&").sort.join("&")
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
end
