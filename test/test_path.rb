require 'test/test_helper'

class TestPath < Test::Unit::TestCase

  def setup
    @data = {
      :key1 => {
        :key1a => [
          "foo",
          "bar",
          "foobar",
          {:findme => "thing"}
        ],
        'key1b' => "findme"
      },
      'findme' => [
        123,
        456,
        {:findme => 123456}
      ],
      :key2 => "foobar",
      :key3 => {
        :key3a => ["val1", "val2", "val3"]
      }
    }
  end


  def test_find_wildcard
    keys = []
    data_points = []

    Kronk::Path.find "*/key1?", @data do |data, key, path|
      keys << key.to_s
      data_points << data
    end

    assert_equal ['key1a', 'key1b'], keys.sort
    assert_equal [@data[:key1], @data[:key1]], data_points
  end


  def test_find_recursive
    keys = []
    paths = []
    data_points = []

    Kronk::Path.find "**/findme", @data do |data, key, path|
      keys << key.to_s
      data_points << data
      paths << path
    end

    expected_paths =
      [[:key1,:key1a,3,:findme], ["findme"], ["findme",2,:findme]]

    assert_equal 3, keys.length
    assert_equal 1, keys.uniq.length
    assert_equal "findme", keys.first

    assert data_points.include?(@data)
    assert data_points.include?(@data[:key1][:key1a].last)
    assert data_points.include?(@data['findme'].last)

    assert_equal expected_paths, (expected_paths | paths)
  end


  def test_find_index
    keys = []
    data_points = []

    Kronk::Path.find "*/*/0|1", @data do |data, key, path|
      keys << key
      data_points << data
    end

    assert_equal [1,0,1,0], keys
    assert_equal 2, data_points.count(@data[:key1][:key1a])
    assert_equal 2, data_points.count(@data[:key3][:key3a])
  end


  def test_find_data_recursive_wildcard_value
    keys = []
    paths = []
    data_points = []

    Kronk::Path.find "**=foo*", @data do |data, key, path|
      keys << key
      data_points << data
      paths << path
    end

    expected_paths = [[:key1,:key1a,0], [:key1,:key1a,2], [:key2]]

    assert_equal [0,2,:key2], ([0,2,:key2] | keys)
    assert_equal expected_paths, (expected_paths | paths)
  end


  def test_parse_path_str_yield
    all_args = []

    Kronk::Path.parse_path_str "path/**/to=foo/item" do |*args|
      all_args << args
    end

    expected = [
      [Kronk::Path::Matcher.new(:key => "path"), false],
      [Kronk::Path::Matcher.new(:key => "to", :value => "foo",
        :recursive => true), false],
      [Kronk::Path::Matcher.new(:key => "item"), true],
    ]

    assert_equal expected, all_args
  end


  def test_parse_path_str_simple
    assert_path %w{path to item}, "path/to/item"
    assert_path %w{path to item}, "///path//to/././item///"
    assert_path %w{path to item}, "///path//to/./item///"
    assert_path %w{path/to item}, "path\\/to/item"

    assert_path %w{path/to item/ i}, "path\\/to/item\\//i"

    assert_path [/\Apath\/\.to\Z/i, /\Aitem\Z/i],
       "path\\/.to/item", Regexp::IGNORECASE

    assert_path ['path', /\Ato|for\Z/, 'item'], "path/to|for/item"
  end


  def test_parse_path_str_value
    assert_path ['path', ['to', 'foo'], 'item'], "path/to=foo/item"
    assert_path ['path', ["*", 'foo'], 'item'],  "path/*=foo/item"
    assert_path ['path', [nil, 'foo'], 'item'],  "path/=foo/item"

    assert_path ['path', ['to', /\Afoo|bar\Z/], 'item'],
      "path/to=foo|bar/item"

    assert_path [/\Apath\Z/i, [/\Ato\Z/i, /\Afoo\Z/i], /\Aitem\Z/i],
      "path/to=foo/item", Regexp::IGNORECASE
  end


  def test_parse_path_str_recur
    assert_path ['path', ['to', 'foo', true], 'item'],    "path/**/to=foo/item"
    assert_path [['path', nil, true], 'to', 'item'],      "**/**/path/to/item"
    assert_path ['path', 'to', 'item', ["*", nil, true]], "path/to/item/**/**"
    assert_path ['path', ["*", 'foo', true], 'item'],     "path/**=foo/item"
  end


  def test_parse_path_str_parent
    assert_path ['path', PARENT, 'item'],              "path/../item"
    assert_path ['path', [PARENT, 'foo'], 'item'],     "path/..=foo/item"
    assert_path ['path', ["*", 'foo', true], 'item'],  "path/**/..=foo/item"
    assert_path ['path', [nil, 'foo', true], 'item'],  "path/**/=foo/item"
    assert_path ['path', ['item', nil, true]],         "path/**/../item"
    assert_path ['path', PARENT, ['item', nil, true]], "path/../**/item"
  end


  def test_parse_regex_opts
    path = "path/to/item///mix"
    opts = Kronk::Path.parse_regex_opts! path

    assert_equal "path/to/item/", path

    expected_opts = Regexp::IGNORECASE | Regexp::EXTENDED | Regexp::MULTILINE
    assert_equal expected_opts, opts
  end


  def test_parse_regex_opts_mix
    opts = Kronk::Path.parse_regex_opts! "path/to/item//m", Regexp::EXTENDED
    assert_equal Regexp::EXTENDED | Regexp::MULTILINE, opts
  end


  def test_parse_regex_opts_none
    assert_nil Kronk::Path.parse_regex_opts!("path/to/item//")
    assert_equal Regexp::EXTENDED,
      Kronk::Path.parse_regex_opts!("path/to/item//", Regexp::EXTENDED)
  end


  private

  PARENT    = Kronk::Path::PARENT
  ANY_VALUE = Kronk::Path::Matcher::ANY_VALUE

  def assert_path match, path, regexp_opt=nil
    match.map! do |i|
      i = [i] unless Array === i
      Kronk::Path::Matcher.new :key => i[0], :value => i[1],
        :recursive => i[2], :regex_opts => regexp_opt
    end

    assert_equal match, Kronk::Path.parse_path_str(path, regexp_opt)
  end
end
