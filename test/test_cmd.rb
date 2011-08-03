require 'test/test_helper'

class TestCmd < Test::Unit::TestCase

  def test_irb
    with_irb_mock do
      resp = Kronk::Response.new mock_resp("200_response.json")

      assert !Kronk::Cmd.irb(resp)

      assert_equal resp, $http_response
      assert_equal resp.parsed_body, $response
    end
  end


  def test_irb_no_parser
    with_irb_mock do
      resp = Kronk::Response.new mock_200_response
      Kronk::Cmd.irb resp
      assert_equal resp, $http_response
      assert_equal resp.body, $response
    end
  end


  def test_load_requires
    assert Kronk.config[:requires].empty?
    mock_require 'foo'
    mock_require 'bar'

    Kronk::Cmd.load_requires ["foo", "bar"]

    assert_require 'foo'
    assert_require 'bar'
  end


  def test_load_requires_from_config
    Kronk.config[:requires] = ['foo', 'bar']
    mock_require 'foo'
    mock_require 'bar'

    Kronk::Cmd.load_requires

    assert_require 'foo'
    assert_require 'bar'
    Kronk.config[:requires] = []
  end


  def test_load_requires_from_config_and_args
    Kronk.config[:requires] = ['foo', 'bar']

    mock_require 'foobar'
    mock_require 'foo'
    mock_require 'bar'

    Kronk::Cmd.load_requires ['foobar']

    assert_require 'foobar'
    assert_require 'foo'
    assert_require 'bar'
    Kronk.config[:requires] = []
  end


  def test_make_config_file
    File.expects(:directory?).with(Kronk::CONFIG_DIR).returns false
    Dir.expects(:mkdir).with Kronk::CONFIG_DIR

    mock_file = StringIO.new
    File.expects(:open).with(Kronk::DEFAULT_CONFIG_FILE, "w+").yields mock_file

    Kronk::Cmd.make_config_file
    mock_file.rewind

    assert_equal Kronk::DEFAULT_CONFIG.to_yaml, mock_file.read
  end


  def test_make_config_file_dir_exists
    File.expects(:directory?).with(Kronk::CONFIG_DIR).returns true
    Dir.expects(:mkdir).with(Kronk::CONFIG_DIR).times(0)

    mock_file = StringIO.new
    File.expects(:open).with(Kronk::DEFAULT_CONFIG_FILE, "w+").yields mock_file

    Kronk::Cmd.make_config_file
    mock_file.rewind

    assert_equal Kronk::DEFAULT_CONFIG.to_yaml, mock_file.read
  end


  def test_parse_data_path_args
    opts = {}
    argv = %w{opt1 opt2 -- path1 path2 -path3}
    Kronk::Cmd.parse_data_path_args opts, argv

    assert_equal %w{path1 path2}, opts[:only_data]
    assert_equal %w{path3}, opts[:ignore_data]
  end


  def test_parse_data_path_args_no_paths
    opts = {}
    argv = %w{opt1 opt2 path1 path2 -path3}
    Kronk::Cmd.parse_data_path_args opts, argv

    assert_nil opts[:only_data]
    assert_nil opts[:ignore_data]
  end


  def test_query_password
    $stderr.expects(:<<).with "Password: "
    $stdin.expects(:gets).returns "mock_password\n"
    $stderr.expects(:<<).with "\n"

    Kronk::Cmd.query_password
  end


  def test_query_password_custom
    $stderr.expects(:<<).with "SAY IT: "
    $stdin.expects(:gets).returns "mock_password\n"
    $stderr.expects(:<<).with "\n"

    Kronk::Cmd.query_password "SAY IT:"
  end


  def test_parse_args_diff_format_mapping
    with_config Hash.new do
      opts = Kronk::Cmd.parse_args %w{uri --ascii}
      assert_equal :ascii_diff, Kronk.config[:diff_format]

      opts = Kronk::Cmd.parse_args %w{uri --color}
      assert_equal :color_diff, Kronk.config[:diff_format]

      opts = Kronk::Cmd.parse_args %w{uri --format color}
      assert_equal 'color', Kronk.config[:diff_format]
    end
  end


  def test_parse_args_completion
    with_config Hash.new do
      file = File.join(File.dirname(__FILE__), "../script/kronk_completion")
      $stdout.expects(:puts).with File.expand_path(file)

      assert_exit 2 do
        Kronk::Cmd.parse_args %w{--completion}
      end
    end
  end


  def test_parse_args_config
    with_config Hash.new do
      YAML.expects(:load_file).with("foobar").returns :foo => "bar"
      Kronk::Cmd.parse_args %w{uri --config foobar}
      assert_equal "bar", Kronk.config[:foo]
    end
  end


  def test_parse_args_kronk_configs
    with_config Hash.new do
      Kronk::Cmd.parse_args %w{uri -q -l --no-opts -V -t 1234}
      assert Kronk.config[:brief]
      assert Kronk.config[:show_lines]
      assert Kronk.config[:no_uri_options]
      assert Kronk.config[:verbose]
      assert_equal 1234, Kronk.config[:timeout]
    end
  end


  def test_parse_args_headers
    opts = Kronk::Cmd.parse_args %w{uri -i FOO -i BAR -iTWO,PART}
    assert_equal %w{FOO BAR TWO PART}, opts[:with_headers]
    assert_equal false, opts[:no_body]

    opts = Kronk::Cmd.parse_args %w{uri -I}
    assert_equal true, opts[:with_headers]
    assert_equal true, opts[:no_body]

    opts = Kronk::Cmd.parse_args %w{uri -I FOO -I BAR -ITWO,PART}
    assert_equal %w{FOO BAR TWO PART}, opts[:with_headers]
    assert_equal true, opts[:no_body]

    opts = Kronk::Cmd.parse_args %w{uri -i}
    assert_equal true, opts[:with_headers]
    assert_equal false, opts[:no_body]
  end


  def test_parse_args_kronk_options
    opts = Kronk::Cmd.parse_args %w{uri1 uri2 --indicies --irb -P FOO
             --prev -R --struct -r lib1,lib2 -rlib3}

    assert_equal [Kronk.config[:cache_file], "uri1"], opts[:uris]
    assert_equal true, opts[:keep_indicies]
    assert_equal true, opts[:irb]
    assert_equal true, opts[:raw]
    assert_equal true, opts[:struct]
    assert_equal %w{lib1 lib2 lib3}, opts[:requires]
    assert_equal "FOO", opts[:parser]
  end


  def test_parse_args_player_options
    
  end


  def test_compare
    io1  = StringIO.new(mock_200_response)
    io2  = StringIO.new(mock_200_response)

    body = mock_200_response.split("\r\n\r\n")[1]
    diff = Kronk::Diff.new(body, body)

    $stdout.expects(:puts).with diff.formatted

    assert Kronk::Cmd.compare(io1, io2), "Expected no diff to succeed"
  end


  def test_compare_failed
    io1  = StringIO.new(mock_200_response)
    io2  = StringIO.new(mock_302_response)

    body1 = mock_200_response.split("\r\n\r\n")[1]
    body2 = mock_302_response.split("\r\n\r\n")[1]
    diff  = Kronk::Diff.new(body1, body2)

    $stdout.expects(:puts).with diff.formatted

    assert !Kronk::Cmd.compare(io1, io2), "Expected diffs to fail"
  end


  def test_request
    io = StringIO.new(mock_200_response)
    $stdout.expects(:puts).with(mock_200_response.split("\r\n\r\n")[1])

    assert Kronk::Cmd.request(io), "Expected 200 response to succeed"
  end


  def test_request_failed
    io = StringIO.new(mock_302_response)
    $stdout.expects(:puts).with(mock_302_response.split("\r\n\r\n")[1])

    assert !Kronk::Cmd.request(io), "Expected 302 response to fail"
  end


  def test_render_with_irb
    kronk = Kronk.new
    io1   = StringIO.new(mock_200_response)
    io2   = StringIO.new(mock_200_response)

    kronk.compare io1, io2
    $stdout.expects(:puts).with(kronk.diff.formatted).never

    with_irb_mock do
      assert !Kronk::Cmd.render(kronk, :irb => true),
        "Expected IRB rendering to return false"
    end
  end


  def test_render_with_diff
    kronk = Kronk.new
    io1   = StringIO.new(mock_200_response)
    io2   = StringIO.new(mock_200_response)

    kronk.compare io1, io2
    $stdout.expects(:puts).with(kronk.diff.formatted).times 2

    assert_equal Kronk::Cmd.render_diff(kronk.diff),
                 Kronk::Cmd.render(kronk, {})
  end


  def test_render_with_response
    kronk = Kronk.new
    io    = StringIO.new(mock_200_response)

    kronk.retrieve io
    $stdout.expects(:puts).with(kronk.response.stringify).times 2

    assert_equal Kronk::Cmd.render_response(kronk.response),
                 Kronk::Cmd.render(kronk, {})
  end


  def test_render_diff
    kronk = Kronk.new
    io1   = StringIO.new(mock_200_response)
    io2   = StringIO.new(mock_200_response)

    kronk.compare io1, io2

    $stdout.expects(:puts).with kronk.diff.formatted
    $stdout.expects(:puts).with("Found 0 diff(s).").never

    assert Kronk::Cmd.render_diff(kronk.diff), "Expected no diff to succeed"
  end


  def test_render_diff_verbose_failed
    kronk = Kronk.new
    io1   = StringIO.new(mock_200_response)
    io2   = StringIO.new(mock_302_response)

    kronk.compare io1, io2

    $stdout.expects(:puts).with kronk.diff.formatted
    $stdout.expects(:puts).with "Found 1 diff(s)."

    with_config :verbose => true do
      assert !Kronk::Cmd.render_diff(kronk.diff), "Expected diffs to fail"
    end
  end


  def test_render_diff_verbose
    kronk = Kronk.new
    io1   = StringIO.new(mock_200_response)
    io2   = StringIO.new(mock_200_response)

    kronk.compare io1, io2

    $stdout.expects(:puts).with kronk.diff.formatted
    $stdout.expects(:puts).with "Found 0 diff(s)."

    with_config :verbose => true do
      assert Kronk::Cmd.render_diff(kronk.diff), "Expected no diff to succeed"
    end
  end


  def test_render_diff_brief
    kronk = Kronk.new
    io1   = StringIO.new(mock_200_response)
    io2   = StringIO.new(mock_200_response)

    kronk.compare io1, io2

    $stdout.expects(:puts).with(kronk.diff.formatted).never
    $stdout.expects(:puts).with "Found 0 diff(s)."

    with_config :brief => true do
      assert Kronk::Cmd.render_diff(kronk.diff), "Expected no diff to succeed"
    end
  end


  def test_render_response
    kronk = Kronk.new
    kronk.retrieve StringIO.new(mock_200_response)

    $stdout.expects(:puts).with kronk.response.stringify
    assert Kronk::Cmd.render_response(kronk.response),
      "Expected render_response success for 200"
  end


  def test_render_response_lines
    with_config :show_lines => true do
      kronk = Kronk.new
      kronk.retrieve StringIO.new(mock_200_response)

      expected = Kronk::Diff.insert_line_nums kronk.response.stringify
      $stdout.expects(:puts).with expected

      assert Kronk::Cmd.render_response(kronk.response),
        "Expected render_response success"
    end
  end


  def test_render_response_verbose
    with_config :verbose => true do
      kronk = Kronk.new
      io    = StringIO.new(mock_200_response)

      $stdout.expects(:<<).with "Reading IO #{io}\n"
      kronk.retrieve io

      expected = kronk.response.stringify
      $stdout.expects(:puts).with expected
      $stdout.expects(:<<).with "\nResp. Time: #{kronk.response.time.to_f}\n"

      assert Kronk::Cmd.render_response(kronk.response),
        "Expected render_response success"
    end
  end


  def test_render_response_failed
    kronk = Kronk.new
    kronk.retrieve StringIO.new(mock_302_response)

    $stdout.expects(:puts).with kronk.response.stringify
    assert !Kronk::Cmd.render_response(kronk.response),
      "Expected render_response to fail on 302"
  end


  def test_verbose
    msg = "BLAH BLAH BLAH"

    with_config :verbose => true do
      $stdout.expects(:<<).with "#{msg}\n"
      Kronk::Cmd.verbose msg
    end

    with_config :verbose => false do
      $stdout.expects(:<<).with("#{msg}\n").times(0)
      Kronk::Cmd.verbose msg
    end
  end


  def test_warn
    msg = "OH NOES!"
    $stderr.expects(:<<).with "Warning: #{msg}\n"
    Kronk::Cmd.warn msg
  end


  def test_windows?
    old_rb_platform = $RUBY_PLATFORM
    $RUBY_PLATFORM  = "something"

    assert !Kronk::Cmd.windows?, "Expected non-windows platform"

    %w{mswin mswindows mingw mingwin cygwin}.each do |platform|
      $RUBY_PLATFORM = platform
      assert Kronk::Cmd.windows?, "Expected windows platform"
    end

    $RUBY_PLATFORM = old_rb_platform
  end
end
