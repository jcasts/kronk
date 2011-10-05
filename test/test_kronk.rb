require 'test/test_helper'

class TestKronk < Test::Unit::TestCase

  def test_default_config
    expected = {
      :async         => 'auto',
      :content_types => {
        'js'      => 'JSON',
        'json'    => 'JSON',
        'plist'   => 'PlistParser',
        'xml'     => 'XMLParser'
      },
      :context      => nil,
      :cache_file   => Kronk::DEFAULT_CACHE_FILE,
      :cookies_file => Kronk::DEFAULT_COOKIES_FILE,
      :history_file => Kronk::DEFAULT_HISTORY_FILE,
      :indentation => 1,
      :default_host => "http://localhost:3000",
      :diff_format  => :ascii_diff,
      :show_lines   => false,
      :use_cookies  => true,
      :requires     => [],
      :uri_options  => {},
      :user_agents  => Kronk::USER_AGENTS
    }

    assert_equal expected, Kronk::DEFAULT_CONFIG
  end


  def test_load_config
    with_config do
      mock_config = {
        :async         => false,
        :content_types => {
          'soap' => "SOAPParser",
          'js'   => "JsEngine"
        },
        :context     => 3,
        :ignore_headers => ["Content-Type"],
        :cache_file  => Kronk::DEFAULT_CACHE_FILE,
        :cookies_file => Kronk::DEFAULT_COOKIES_FILE,
        :history_file => Kronk::DEFAULT_HISTORY_FILE,
        :indentation => 1,
        :show_lines  => false,
        :use_cookies => true,
        :requires    => [],
        :uri_options => {'example.com' => {:parser => 'JSON'}},
        :user_agents => {:win_ie6 => 'piece of crap browser'},
        :foo => :bar
      }

      YAML.expects(:load_file).with(Kronk::DEFAULT_CONFIG_FILE).
        returns mock_config

      Kronk.load_config

      YAML.expects(:load_file).with("foobar").
        returns mock_config

      Kronk.load_config "foobar"

      expected = {
        :async         => false,
        :content_types => {
          'soap'  => "SOAPParser",
          'js'    => "JsEngine",
          'json'  => "JSON",
          'plist' => "PlistParser",
          'xml'   => "XMLParser"
        },
        :context     => 3,
        :default_host => "http://localhost:3000",
        :diff_format => :ascii_diff,
        :cache_file  => Kronk::DEFAULT_CACHE_FILE,
        :cookies_file => Kronk::DEFAULT_COOKIES_FILE,
        :history_file => Kronk::DEFAULT_HISTORY_FILE,
        :indentation => 1,
        :requires    => [],
        :show_lines  => false,
        :use_cookies => true,
        :ignore_headers => ["Content-Type"],
        :uri_options => {'example.com' => {:parser => 'JSON'}},
        :user_agents =>
          Kronk::USER_AGENTS.merge(:win_ie6 => 'piece of crap browser'),
        :foo => :bar
      }

      assert_equal expected, Kronk.config
    end
  end


  def test_parser_for
    assert_equal JSON, Kronk.parser_for('json')
    assert_equal Kronk::XMLParser, Kronk.parser_for('xml')
    assert_equal Kronk::PlistParser, Kronk.parser_for('plist')
  end


  def test_history
    Kronk.instance_variable_set "@history", nil
    File.expects(:file?).with(Kronk.config[:history_file]).returns true
    File.expects(:read).with(Kronk.config[:history_file]).
      returns "history1\nhistory2"

    assert_equal %w{history1 history2}, Kronk.history
  end


  def test_history_no_file
    Kronk.instance_variable_set "@history", nil
    File.expects(:file?).with(Kronk.config[:history_file]).returns false
    File.expects(:read).with(Kronk.config[:history_file]).never

    assert_equal [], Kronk.history
  end


  def test_save_history
    Kronk.instance_variable_set "@history", %w{hist1 hist2 hist1 hist3}
    file = StringIO.new
    File.expects(:open).with(Kronk.config[:history_file], "w").yields file

    Kronk.save_history

    file.rewind
    assert_equal "hist1\nhist2\nhist3", file.read
  end


  def test_find_const
    assert_equal Nokogiri::XML::Document,
                 Kronk.find_const("Nokogiri::XML::Document")

    assert_equal JSON, Kronk.find_const("JSON")

    assert_equal Kronk::XMLParser, Kronk.find_const("XMLParser")
  end


  def test_find_const_file
    $".delete_if{|path| path =~ %r{kronk/diff/ascii_format.rb}}
    Kronk::Diff.send(:remove_const, :AsciiFormat)
    assert_raises(NameError){ Kronk::Diff::AsciiFormat }

    Kronk.find_const 'kronk/diff/ascii_format'
    assert Kronk::Diff::AsciiFormat
  end


  def test_find_const_file_rb
    $".delete_if{|path| path =~ %r{kronk/diff/ascii_format.rb}}
    Kronk::Diff.send(:remove_const, :AsciiFormat)
    assert_raises(NameError){ Kronk::Diff::AsciiFormat }

    Kronk.find_const 'kronk/diff/ascii_format.rb'
    assert Kronk::Diff::AsciiFormat
  end


  def test_find_const_file_pair
    $".delete_if{|path| path =~ %r{kronk/diff/ascii_format.rb}}
    Kronk::Diff.send(:remove_const, :AsciiFormat)
    assert_raises(NameError){ Kronk::Diff::AsciiFormat }

    Kronk.find_const 'Kronk::Diff::AsciiFormat:kronk/diff/ascii_format'
    assert Kronk::Diff::AsciiFormat
  end


  def test_find_const_file_pair_rb
    $".delete_if{|path| path =~ %r{kronk/diff/ascii_format.rb}}
    Kronk::Diff.send(:remove_const, :AsciiFormat)
    assert_raises(NameError){ Kronk::Diff::AsciiFormat }

    Kronk.find_const 'Kronk::Diff::AsciiFormat:kronk/diff/ascii_format.rb'
    assert Kronk::Diff::AsciiFormat
  end


  def test_find_const_file_pair_rb_expanded
    $".delete_if{|path| path =~ %r{kronk/diff/ascii_format.rb}}
    Kronk::Diff.send(:remove_const, :AsciiFormat)
    assert_raises(NameError){ Kronk::Diff::AsciiFormat }

    Kronk.find_const 'Kronk::Diff::AsciiFormat:lib/kronk/diff/ascii_format.rb'
    assert Kronk::Diff::AsciiFormat
  end


  def test_options_for_uri
    with_uri_options do
      assert_equal mock_uri_options['example'],
        Kronk.new.options_for_uri("http://example.com/path")

      assert_equal Hash.new,
        Kronk.new.options_for_uri("http://thing.com/path")
    end
  end


  def test_options_for_uri_query
    data = {
      "add" => "this",
      "foo" => {
        "bar1" => "one",
        "bar2" => 2,
        "bar3" => "three"},
      "key"=>"otherval"}

    expected = {:query => data, :data => data}

    with_uri_options do
      new_data = {
        "add" => "this",
        "foo" => {'bar2' => 2, 'bar3' => "three"},
        "key" => "otherval"
      }

      %w{uri_query hash_query}.each do |qtype|
        opts = Kronk.new(:query => data, :data => data).
                options_for_uri("http://#{qtype}.com")

        assert_equal expected, opts
      end

      opts = Kronk.new.options_for_uri("http://uri_query.com")
      assert_equal mock_uri_options['uri_query'], opts
    end
  end


  def test_options_for_uri_headers
    with_uri_options do
      opts = Kronk.new(:headers => {'hdr2' => 2, 'hdr3' => 3}).
              options_for_uri("http://headers.example.com")

      expected = {
        :headers => {
          'hdr1' => 'one',
          'hdr2' => 2,
          'hdr3' => 3
        },
        :parser => "XMLParser"
      }

      assert_equal expected, opts
    end
  end


  def test_options_for_uri_auth
    with_uri_options do
      opts = Kronk.new(:auth => {:username => "bob"}).
              options_for_uri("http://auth.example.com")

      expected = {
        :auth => {
          :username => "bob",
          :password => "pass"
        },
        :parser => "XMLParser"
      }

      assert_equal expected, opts
    end
  end


  def test_options_for_uri_proxy
    with_uri_options do
      expected = {
        :proxy => {
          :address  => "proxy.com",
          :port     => 1234,
          :username => "user",
          :password => "pass"
        }
      }

      opts = Kronk.new(:proxy => "proxy.com").
              options_for_uri("http://proxy.com")

      assert_equal expected, opts

      opts = Kronk.new(:proxy => {:address => "proxy.com"}).
              options_for_uri("http://proxy.com")

      assert_equal expected, opts
    end
  end


  def test_options_for_uri_str_proxy
    with_uri_options do
      expected = {
        :proxy => {
          :address  => "someproxy.com",
          :username => "user",
          :password => "pass"
        }
      }

      opts = Kronk.new(:proxy => {:username => "user", :password => "pass"}).
              options_for_uri("http://strprox.com")

      assert_equal expected, opts

      opts = Kronk.new(:proxy => "proxy.com").
              options_for_uri("http://strprox.com")

      assert_equal "proxy.com", opts[:proxy]
    end
  end


  def test_options_for_uri_show_headers
    with_uri_options do
      %w{withhdrs withstrhdrs withtruehdrs}.each do |type|
        opts = Kronk.new(:show_headers => true).
                options_for_uri "http://#{type}.com"

        assert_equal true, opts[:show_headers]
      end
    end
  end


  def test_options_for_uri_show_headers_arr
    with_uri_options do
      %w{withhdrs withstrhdrs}.each do |type|
        opts = Kronk.new(:show_headers => %w{hdr2 hdr3}).
                options_for_uri "http://#{type}.com"

        assert_equal %w{hdr1 hdr2 hdr3}.sort, opts[:show_headers].sort
      end

      opts = Kronk.new(:show_headers => %w{hdr2 hdr3}).
              options_for_uri "http://withtruehdrs.com"

      assert_equal %w{hdr2 hdr3}, opts[:show_headers]
    end
  end


  def test_options_for_uri_data_paths
    expected = {
      :only_data   => %w{path1 path2 path3},
      :ignore_data => "ign1",
    }

    with_uri_options do
      opts = Kronk.new(:only_data => %w{path2 path3}).
              options_for_uri "http://focus_data.com"

      opts[:only_data].sort!

      assert_equal expected, opts
    end
  end


  def test_compare_raw
    diff = Kronk.compare "test/mocks/200_response.json",
                         "test/mocks/200_response.xml",
                         :show_headers => true,
                         :raw => true

    resp1 = Kronk.request "test/mocks/200_response.json",
                             :show_headers => true,
                             :raw => true

    resp2 = Kronk.request "test/mocks/200_response.xml",
                             :show_headers => true,
                             :raw => true

    exp_diff = Kronk::Diff.new resp1.selective_string(:show_headers => true),
                               resp2.selective_string(:show_headers => true),
                               :labels => [
                                 "test/mocks/200_response.json",
                                 "test/mocks/200_response.xml"
                                ]

    assert_equal exp_diff.formatted, diff.formatted
  end


  def test_load_cookie_jar
    Kronk.clear_cookies!
    mock_cookie_jar = YAML.load_file("test/mocks/cookies.yml")

    File.expects(:file?).with(Kronk::DEFAULT_COOKIES_FILE).returns true
    YAML.expects(:load_file).with(Kronk::DEFAULT_COOKIES_FILE).
      returns mock_cookie_jar

    cookie_jar = Kronk.load_cookie_jar

    assert CookieJar::Jar === cookie_jar
    assert !cookie_jar.get_cookies("http://rubygems.org/").empty?
  end


  def test_load_cookie_jar_no_file
    Kronk.clear_cookies!
    mock_cookie_jar = YAML.load_file("test/mocks/cookies.yml")

    File.expects(:file?).with(Kronk::DEFAULT_COOKIES_FILE).returns false
    YAML.expects(:load_file).with(Kronk::DEFAULT_COOKIES_FILE).never

    cookie_jar = Kronk.load_cookie_jar
    assert cookie_jar.get_cookies("http://rubygems.org/").empty?
  end


  def test_save_cookie_jar
    mock_file = mock "mockfile"
    mock_file.expects(:write).with Kronk.cookie_jar.to_yaml
    File.expects(:open).with(Kronk::DEFAULT_COOKIES_FILE, "w").yields mock_file

    Kronk.save_cookie_jar
  end


  def test_clear_cookies
    Kronk.instance_variable_set "@cookie_jar", nil
    mock_cookie_jar = YAML.load_file("test/mocks/cookies.yml")

    File.expects(:file?).with(Kronk::DEFAULT_COOKIES_FILE).returns true
    YAML.expects(:load_file).with(Kronk::DEFAULT_COOKIES_FILE).
      returns mock_cookie_jar

    assert !Kronk.cookie_jar.get_cookies("http://rubygems.org/").empty?

    Kronk.clear_cookies!

    assert Kronk.cookie_jar.get_cookies("http://rubygems.org/").empty?
  end


  def test_cookie_jar
    assert_equal Kronk.instance_variable_get("@cookie_jar"), Kronk.cookie_jar
  end


  def test_compare_data
    diff = Kronk.compare "test/mocks/200_response.json",
                         "test/mocks/200_response.xml",
                         :show_headers => true

    resp1 = Kronk.request "test/mocks/200_response.json",
                             :show_headers => true

    resp2 = Kronk.request "test/mocks/200_response.xml",
                             :show_headers => true

    exp_diff = Kronk::Diff.new_from_data \
                  resp1.selective_data(:show_headers => true),
                  resp2.selective_data(:show_headers => true),
                  :labels => [
                    "test/mocks/200_response.json",
                    "test/mocks/200_response.xml"
                   ]

    assert_equal exp_diff.formatted, diff.formatted
  end


  def test_follow_redirect_infinite
    res = Kronk::Response.new mock_301_response
    req = Kronk::Request.new "http://www.google.com/"
    req.stubs(:retrieve).returns res

    Kronk::Request.stubs(:new).
      with("http://www.google.com/",{:follow_redirects => true}).returns req

    Kronk::Request.expects(:new).
      with("http://www.google.com/", :follow_redirects => true).returns req

    assert_raises Timeout::Error do
      timeout(2) do
        Kronk.request "http://www.google.com/", :follow_redirects => true
      end
    end
  end


  def test_num_follow_redirect
    res = Kronk::Response.new mock_301_response
    req = Kronk::Request.new "http://www.google.com/"
    req.stubs(:retrieve).returns res

    Kronk::Request.expects(:new).
      with("http://www.google.com/",{:follow_redirects => 3}).returns(req).
      times(3)

    Kronk::Request.expects(:new).
      with("http://www.google.com/", :follow_redirects => 3).returns req

    Kronk.request "http://www.google.com/", :follow_redirects => 3
  end


  def test_follow_redirect_no_redirect
    res = Kronk::Response.new mock_200_response
    req = Kronk::Request.new "http://www.google.com/"
    req.stubs(:request).returns res

    Kronk::Request.expects(:new).with("http://www.google.com/",{}).never
    Kronk::Request.expects(:new).
      with("http://www.google.com/", :follow_redirects => true).returns req

    Kronk.request "http://www.google.com/", :follow_redirects => true
  end


  def test_do_not_follow_redirect
    res = Kronk::Response.new mock_302_response
    req = Kronk::Request.new "http://www.google.com/"
    req.stubs(:request).returns res

    Kronk::Request.expects(:new).with("http://www.google.com/",{}).never
    Kronk::Request.expects(:new).
      with("http://www.google.com/", :follow_redirects => false).returns req

    Kronk.request "http://www.google.com/", :follow_redirects => false
  end


  def test_compare_data_inst
    kronk = Kronk.new :show_headers => true
    diff  = kronk.compare "test/mocks/200_response.json",
                          "test/mocks/200_response.xml"

    json_resp = Kronk::Response.new(File.read("test/mocks/200_response.json"))
    xml_resp  = Kronk::Response.new(File.read("test/mocks/200_response.xml"))

    assert_equal xml_resp.raw,  kronk.response.raw
    assert_equal xml_resp.raw,  kronk.responses.last.raw
    assert_equal json_resp.raw, kronk.responses.first.raw
    assert_equal 2,             kronk.responses.length
    assert_equal diff,          kronk.diff

    resp1 = kronk.request "test/mocks/200_response.xml"
    resp2 = kronk.request "test/mocks/200_response.json"

    assert_equal json_resp.raw, kronk.response.raw
    assert_equal json_resp.raw, kronk.responses.last.raw
    assert_equal 1,             kronk.responses.length
    assert_equal nil,           kronk.diff

    exp_diff = Kronk::Diff.new_from_data \
                  resp2.selective_data(:show_headers => true),
                  resp1.selective_data(:show_headers => true),
                  :labels => [
                    "test/mocks/200_response.json",
                    "test/mocks/200_response.xml"
                   ]


    assert_equal exp_diff.formatted, diff.formatted
  end


  private

  def mock_uri_options
    {
      'example'     => {
        :parser => "XMLParser"
      },
      'example.com' => {
        :parser => "PlistParser"
      },
      'uri_query'   => {
        :query => "foo[bar1]=one&foo[bar2]=two&key=val",
        :data  => "foo[bar1]=one&foo[bar2]=two&key=val"
      },
      'hash_query'  => {
        :query => {
          'foo' => {'bar1'=>'one', 'bar2'=>'two'},
          'key' => "val"
        },
        :data  => {
          'foo' => {'bar1'=>'one', 'bar2'=>'two'},
          'key' => "val"
        }
      },
      'headers'     => {
        :headers => {
          'hdr1' => 'one',
          'hdr2' => 'two'
        }
      },
      'auth'        => {
        :auth => {
          :username => "user",
          :password => "pass"
        }
      },
      'proxy'       => {
        :proxy => {
          :username => "user",
          :password => "pass",
          :address  => "someproxy.com",
          :port     => 1234
        }
      },
      'strprox'     => {
        :proxy => "someproxy.com"
      },
      'withhdrs'    => {
        :show_headers => %w{hdr1 hdr2 hdr3}
      },
      'withstrhdrs' => {
        :show_headers => "hdr1"
      },
      'withtruehdrs' => {
        :show_headers => true
      },
      'focus_data'   => {
        :only_data      => %w{path1 path2},
        :ignore_data    => "ign1"
      }
    }
  end


  def with_uri_options
    old_uri_opts = Kronk.config[:uri_options].dup
    Kronk.config[:uri_options] = mock_uri_options

    yield if block_given?

  ensure
    Kronk.config[:uri_options] = old_uri_opts
  end
end
