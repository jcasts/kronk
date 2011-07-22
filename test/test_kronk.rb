require 'test/test_helper'

class TestKronk < Test::Unit::TestCase

  def test_default_config
    expected = {
      :content_types => {
        'js'      => 'JSON',
        'json'    => 'JSON',
        'plist'   => 'PlistParser',
        'xml'     => 'XMLParser'
      },
      :cache_file   => Kronk::DEFAULT_CACHE_FILE,
      :cookies_file => Kronk::DEFAULT_COOKIES_FILE,
      :history_file => Kronk::DEFAULT_HISTORY_FILE,
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
    mock_config = {
      :content_types => {
        'soap' => "SOAPParser",
        'js'   => "JsEngine"
      },
      :ignore_headers => ["Content-Type"],
      :cache_file  => Kronk::DEFAULT_CACHE_FILE,
      :cookies_file => Kronk::DEFAULT_COOKIES_FILE,
      :history_file => Kronk::DEFAULT_HISTORY_FILE,
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

    expected = {
      :content_types => {
        'soap'  => "SOAPParser",
        'js'    => "JsEngine",
        'json'  => "JSON",
        'plist' => "PlistParser",
        'xml'   => "XMLParser"
      },
      :default_host => "http://localhost:3000",
      :diff_format => :ascii_diff,
      :cache_file  => Kronk::DEFAULT_CACHE_FILE,
      :cookies_file => Kronk::DEFAULT_COOKIES_FILE,
      :history_file => Kronk::DEFAULT_HISTORY_FILE,
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


  def test_make_config_file
    file = mock 'file'
    file.expects(:<<).with Kronk::DEFAULT_CONFIG.to_yaml
    File.expects(:directory?).with(Kronk::CONFIG_DIR).returns false
    Dir.expects(:mkdir).with Kronk::CONFIG_DIR
    File.expects(:open).with(Kronk::DEFAULT_CONFIG_FILE, "w+").yields file

    Kronk.make_config_file
  end


  def test_parser_for
    assert_equal JSON, Kronk.parser_for('json')
    assert_equal Kronk::XMLParser, Kronk.parser_for('xml')
    assert_equal Kronk::PlistParser, Kronk.parser_for('plist')
  end


  def test_load_requires
    old_requires = Kronk.config[:requires]
    Kronk.config[:requires] = ["mock_lib1"]

    assert_raises LoadError do
      Kronk.load_requires
    end

    Kronk.config[:requires] = old_requires
  end


  def test_load_requires_nil
    old_requires = Kronk.config[:requires]
    Kronk.config[:requires] = nil

    assert_nil Kronk.load_requires

    Kronk.config[:requires] = old_requires
  end


  def test_find_const
    assert_equal Nokogiri::XML::Document,
                 Kronk.find_const("Nokogiri::XML::Document")

    assert_equal JSON, Kronk.find_const("JSON")

    assert_equal Kronk::XMLParser, Kronk.find_const("XMLParser")
  end


  def test_merge_options_for_uri
    with_uri_options do
      assert_equal mock_uri_options['example'],
        Kronk.merge_options_for_uri("http://example.com/path")

      assert_equal Hash.new,
        Kronk.merge_options_for_uri("http://thing.com/path")
    end
  end


  def test_merge_options_for_uri_query
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
        opts = Kronk.merge_options_for_uri("http://#{qtype}.com",
                :query => data, :data => data)

        assert_equal expected, opts
      end

      opts = Kronk.merge_options_for_uri("http://uri_query.com")
      assert_equal mock_uri_options['uri_query'], opts
    end
  end


  def test_merge_options_for_uri_headers
    with_uri_options do
      opts = Kronk.merge_options_for_uri("http://headers.example.com",
              :headers => {'hdr2' => 2, 'hdr3' => 3})

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


  def test_merge_options_for_uri_auth
    with_uri_options do
      opts = Kronk.merge_options_for_uri("http://auth.example.com",
              :auth => {:username => "bob"})

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


  def test_merge_options_for_uri_proxy
    with_uri_options do
      expected = {
        :proxy => {
          :address  => "proxy.com",
          :port     => 1234,
          :username => "user",
          :password => "pass"
        }
      }

      opts = Kronk.merge_options_for_uri("http://proxy.com",
              :proxy => "proxy.com")

      assert_equal expected, opts

      opts = Kronk.merge_options_for_uri("http://proxy.com",
              :proxy => {:address => "proxy.com"})

      assert_equal expected, opts
    end
  end


  def test_merge_options_for_uri_str_proxy
    with_uri_options do
      expected = {
        :proxy => {
          :address  => "someproxy.com",
          :username => "user",
          :password => "pass"
        }
      }

      opts = Kronk.merge_options_for_uri("http://strprox.com",
              :proxy => {:username => "user", :password => "pass"})

      assert_equal expected, opts

      opts = Kronk.merge_options_for_uri("http://strprox.com",
              :proxy => "proxy.com")

      assert_equal "proxy.com", opts[:proxy]
    end
  end


  def test_merge_options_for_uri_with_headers
    with_uri_options do
      %w{withhdrs withstrhdrs withtruehdrs}.each do |type|
        opts = Kronk.merge_options_for_uri "http://#{type}.com",
                :with_headers => true

        assert_equal true, opts[:with_headers]
      end
    end
  end


  def test_merge_options_for_uri_with_headers_arr
    with_uri_options do
      %w{withhdrs withstrhdrs}.each do |type|
        opts = Kronk.merge_options_for_uri "http://#{type}.com",
                :with_headers => %w{hdr2 hdr3}

        assert_equal %w{hdr1 hdr2 hdr3}.sort, opts[:with_headers].sort
      end

      opts = Kronk.merge_options_for_uri "http://withtruehdrs.com",
              :with_headers => %w{hdr2 hdr3}

      assert_equal %w{hdr2 hdr3}, opts[:with_headers]
    end
  end


  def test_merge_options_for_uri_data_paths
    expected = {
      :only_data        => %w{path1 path2 path3},
      :ignore_data      => "ign1",
    }

    with_uri_options do
      opts = Kronk.merge_options_for_uri "http://focus_data.com",
              :only_data => %w{path2 path3}

      opts[:only_data].sort!

      assert_equal expected, opts
    end
  end


  def test_compare_raw
    diff = Kronk.compare "test/mocks/200_response.json",
                         "test/mocks/200_response.xml",
                         :with_headers => true,
                         :raw => true

    resp1 = Kronk.retrieve "test/mocks/200_response.json",
                             :with_headers => true,
                             :raw => true

    resp2 = Kronk.retrieve "test/mocks/200_response.xml",
                             :with_headers => true,
                             :raw => true

    exp_diff = Kronk::Diff.new resp1.selective_string(:with_headers => true),
                               resp2.selective_string(:with_headers => true)

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
                         :with_headers => true

    resp1 = Kronk.retrieve "test/mocks/200_response.json",
                             :with_headers => true

    resp2 = Kronk.retrieve "test/mocks/200_response.xml",
                             :with_headers => true

    exp_diff = Kronk::Diff.new_from_data \
                  resp1.selective_data(:with_headers => true),
                  resp2.selective_data(:with_headers => true)

    assert_equal exp_diff.formatted, diff.formatted
  end


  def test_parse_data_path_args
    options = {}
    argv = %w{this is --argv -- one -two -- -three four :parents :-not_parents}

    Kronk::Cmd.expects(:warn).times(2)

    options = Kronk::Cmd.parse_data_path_args options, argv

    assert_equal %w{one four}, options[:only_data]
    assert_equal %w{two - three}, options[:ignore_data]

    assert_equal %w{this is --argv}, argv
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
        :with_headers => %w{hdr1 hdr2 hdr3}
      },
      'withstrhdrs' => {
        :with_headers => "hdr1"
      },
      'withtruehdrs' => {
        :with_headers => true
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
