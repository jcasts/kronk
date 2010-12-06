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
      :requires    => []
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
      :requires    => [],
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
      :ignore_headers => ["Content-Type"],
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
end
