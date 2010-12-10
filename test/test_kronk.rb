require 'test/test_helper'

class TestKronk < Test::Unit::TestCase

  def test_default_config
    expected = {
      :content_types  => {
        'js'      => 'JSON',
        'json'    => 'JSON',
        'plist'   => 'PlistParser',
        'xml'     => 'XMLParser'
      },
      :cache_file  => Kronk::DEFAULT_CACHE_FILE,
      :diff_format => :ascii_diff,
      :show_lines  => false,
      :requires    => [],
      :uri_options => {},
      :user_agents => Kronk::USER_AGENTS
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
      :show_lines  => false,
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
      :diff_format => :ascii_diff,
      :cache_file  => Kronk::DEFAULT_CACHE_FILE,
      :requires    => [],
      :show_lines  => false,
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


  def test_options_for_uri
    old_uri_opts = Kronk.config[:uri_options].dup
    Kronk.config[:uri_options] = {
      'example'     => 'options1',
      'example.com' => 'options2'
    }

    assert_equal 'options1', Kronk.options_for_uri("http://example.com/path")
    assert_equal Hash.new, Kronk.options_for_uri("http://thing.com/path")

    Kronk.config[:uri_options] = old_uri_opts
  end


  def test_compare_raw
    diff = Kronk.compare "test/mocks/200_response.json",
                         "test/mocks/200_response.xml",
                         :with_headers => true,
                         :raw => true

    resp1 = Kronk::Request.retrieve "test/mocks/200_response.json",
                             :with_headers => true,
                             :raw => true

    resp2 = Kronk::Request.retrieve "test/mocks/200_response.xml",
                             :with_headers => true,
                             :raw => true

    exp_diff = Kronk::Diff.new resp1.selective_string(:with_headers => true),
                               resp2.selective_string(:with_headers => true)

    assert_equal exp_diff.formatted, diff.formatted
  end


  def test_compare_data
    diff = Kronk.compare "test/mocks/200_response.json",
                         "test/mocks/200_response.xml",
                         :with_headers => true

    resp1 = Kronk::Request.retrieve "test/mocks/200_response.json",
                             :with_headers => true

    resp2 = Kronk::Request.retrieve "test/mocks/200_response.xml",
                             :with_headers => true

    exp_diff = Kronk::Diff.new_from_data \
                  resp1.selective_data(:with_headers => true),
                  resp2.selective_data(:with_headers => true)

    assert_equal exp_diff.formatted, diff.formatted
  end


  def test_raw_diff
    diff = Kronk.raw_diff "test/mocks/200_response.json",
                          "test/mocks/200_response.xml",
                          :with_headers => true

    resp1 = Kronk::Request.retrieve "test/mocks/200_response.json",
                             :with_headers => true,
                             :raw => true

    resp2 = Kronk::Request.retrieve "test/mocks/200_response.xml",
                             :with_headers => true,
                             :raw => true

    exp_diff = Kronk::Diff.new resp1.selective_string(:with_headers => true),
                               resp2.selective_string(:with_headers => true)

    assert_equal exp_diff.formatted, diff.formatted
  end


  def test_data_diff
    diff = Kronk.data_diff "test/mocks/200_response.json",
                           "test/mocks/200_response.xml",
                           :with_headers => true

    resp1 = Kronk::Request.retrieve "test/mocks/200_response.json",
                             :with_headers => true

    resp2 = Kronk::Request.retrieve "test/mocks/200_response.xml",
                             :with_headers => true

    exp_diff = Kronk::Diff.new_from_data \
                  resp1.selective_data(:with_headers => true),
                  resp2.selective_data(:with_headers => true)

    assert_equal exp_diff.formatted, diff.formatted
  end


  def test_parse_data_path_args
    options = {}
    argv = %w{this is --argv -- one -two -- -three four :parents :-not_parents}

    options = Kronk.parse_data_path_args options, argv

    assert_equal %w{one four}, options[:only_data]
    assert_equal %w{two - three}, options[:ignore_data]

    assert_equal %w{parents}, options[:only_data_with]
    assert_equal %w{not_parents}, options[:ignore_data_with]

    assert_equal %w{this is --argv}, argv
  end
end
