require 'test/test_helper'

class TestCmd < Test::Unit::TestCase

  def test_irb
    with_irb_mock do
      resp = Kronk::Response.new mock_resp("200_response.json")

      Kronk::Cmd.irb resp

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


  def test_render_response
    kronk = Kronk.new
    kronk.retrieve StringIO.new(mock_200_response)

    $stdout.expects(:puts).with kronk.response.stringify
    assert Kronk::Cmd.render_response(kronk), "Expected render_response success"
  end


  def test_render_response_lines
    with_config :show_lines => true do
      kronk = Kronk.new
      kronk.retrieve StringIO.new(mock_200_response)

      expected = Kronk::Diff.insert_line_nums kronk.response.stringify
      $stdout.expects(:puts).with expected

      assert Kronk::Cmd.render_response(kronk),
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

      assert Kronk::Cmd.render_response(kronk),
        "Expected render_response success"
    end
  end


  def test_render_response_failed
    kronk = Kronk.new
    kronk.retrieve StringIO.new(mock_302_response)

    $stdout.expects(:puts).with kronk.response.stringify
    assert !Kronk::Cmd.render_response(kronk),
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
