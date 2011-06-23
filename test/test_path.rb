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


  def test_each_data_item_hash
    hash = {
      :a => 1,
      :b => 2,
      :c => 3
    }

    keys = []
    values = []

    Kronk::Path.each_data_item hash do |key, val|
      keys << key
      values << val
    end

    assert_equal keys, (keys | hash.keys)
    assert_equal values, (values | hash.values)
  end


  def test_each_data_item_array
    ary = [:a, :b, :c]

    keys = []
    values = []

    Kronk::Path.each_data_item ary do |key, val|
      keys << key
      values << val
    end

    assert_equal [2,1,0], keys
    assert_equal ary.reverse, values
  end


  def test_match_data_item
    assert Kronk::Path.match_data_item(:key, "key")
    assert Kronk::Path.match_data_item("key", :key)

    assert Kronk::Path.match_data_item(/key/, "foo_key")
    assert !Kronk::Path.match_data_item("foo_key", /key/)
    assert Kronk::Path.match_data_item(/key/, /key/)

    assert Kronk::Path.match_data_item(Kronk::Path::ANY_VALUE, "foo_key")
    assert !Kronk::Path.match_data_item("foo_key", Kronk::Path::ANY_VALUE)

    assert Kronk::Path.match_data_item(1..3, 1)
    assert !Kronk::Path.match_data_item(1, 1..3)
    assert Kronk::Path.match_data_item(1..3, 1..3)
  end


  def test_find_match
    keys = []

    Kronk::Path.find_match @data, /key/ do |data, key|
      keys << key.to_s
      assert_equal @data, data
    end

    assert_equal ['key1', 'key2', 'key3'], keys.sort
  end


  def test_find_match_recursive
    keys = []
    data_points = []

    Kronk::Path.find_match @data, :findme, ANY_VALUE, true do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert_equal 3, keys.length
    assert_equal 1, keys.uniq.length
    assert_equal "findme", keys.first

    assert_equal 3, data_points.length
    assert data_points.include?(@data)
    assert data_points.include?({:findme => "thing"})
    assert data_points.include?({:findme => 123456})
  end


  def test_find_match_value
    keys = []
    data_points = []

    Kronk::Path.find_match @data, ANY_VALUE, "findme" do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert keys.empty?
    assert data_points.empty?

    Kronk::Path.find_match @data, ANY_VALUE, "findme", true do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert_equal ['key1b'], keys
    assert_equal [@data[:key1]], data_points
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


  def test_parse_path_item_range
    assert_equal 1..4,   Kronk::Path.parse_path_item("1..4")
    assert_equal 1...4,  Kronk::Path.parse_path_item("1...4")
    assert_equal "1..4", Kronk::Path.parse_path_item("\\1..4")
    assert_equal "1..4", Kronk::Path.parse_path_item("1\\..4")
    assert_equal "1..4", Kronk::Path.parse_path_item("1.\\.4")
    assert_equal "1..4", Kronk::Path.parse_path_item("1..\\4")
    assert_equal "1..4", Kronk::Path.parse_path_item("1..4\\")
  end


  def test_parse_path_item_index_length
    assert_equal 2...6, Kronk::Path.parse_path_item("2,4")
    assert_equal "2,4", Kronk::Path.parse_path_item("\\2,4")
    assert_equal "2,4", Kronk::Path.parse_path_item("2\\,4")
    assert_equal "2,4", Kronk::Path.parse_path_item("2,\\4")
    assert_equal "2,4", Kronk::Path.parse_path_item("2,4\\")
  end


  def test_parse_path_item_anyval
    assert_equal Kronk::Path::ANY_VALUE, Kronk::Path.parse_path_item("*")
    assert_equal Kronk::Path::ANY_VALUE, Kronk::Path.parse_path_item("")
    assert_equal Kronk::Path::ANY_VALUE, Kronk::Path.parse_path_item("**?*?*?")
    assert_equal Kronk::Path::ANY_VALUE, Kronk::Path.parse_path_item(nil)
  end


  def test_parse_path_item_regex
    assert_equal(/\A(test.*)\Z/,     Kronk::Path.parse_path_item("test*"))
    assert_equal(/\A(.?test.*)\Z/,   Kronk::Path.parse_path_item("?test*"))
    assert_equal(/\A(\?test.*)\Z/,   Kronk::Path.parse_path_item("\\?test*"))
    assert_equal(/\A(.?test\*.*)\Z/, Kronk::Path.parse_path_item("?test\\**"))
    assert_equal(/\A(.?test.*)\Z/,   Kronk::Path.parse_path_item("?test*?**??"))
    assert_equal(/\A(a|b)\Z/,        Kronk::Path.parse_path_item("a|b"))
    assert_equal(/\A(a|b(c|d))\Z/,   Kronk::Path.parse_path_item("a|b(c|d)"))

    assert_equal(/\A(a|b(c|d))\Z/i,
      Kronk::Path.parse_path_item("a|b(c|d)", Regexp::IGNORECASE))
  end


  def test_parse_path_item_string
    assert_equal "a|b", Kronk::Path.parse_path_item("a\\|b")
    assert_equal "a(b", Kronk::Path.parse_path_item("a\\(b")
    assert_equal "a?b", Kronk::Path.parse_path_item("a\\?b")
    assert_equal "a*b", Kronk::Path.parse_path_item("a\\*b")
  end


  def test_parse_path_item_passthru
    assert_equal Kronk::Path::PARENT,
      Kronk::Path.parse_path_item(Kronk::Path::PARENT)

    assert_equal :thing, Kronk::Path.parse_path_item(:thing)
  end


  def test_parse_path_str_yield
    all_args = []

    Kronk::Path.parse_path_str "path/**/to=foo/item" do |*args|
      all_args << args
    end

    expected = [
      ["path", ANY_VALUE, false, false],
      ["to", "foo", true, false],
      ["item", ANY_VALUE, false, true],
    ]

    assert_equal expected, all_args
  end


  def test_parse_path_str_simple
    assert_path %w{path to item}, "path/to/item"
    assert_path %w{path to item}, "///path//to/././item///"
    assert_path %w{path to item}, "///path//to/./item///"
    assert_path %w{path/to item}, "path\\/to/item"

    assert_path %w{path/to item/ i}, "path\\/to/item\\//i"

    assert_path [/\A(path\/\.to)\Z/i, /\A(item)\Z/i],
       "path\\/.to/item", Regexp::IGNORECASE

    assert_path ['path', /\A(to|for)\Z/, 'item'], "path/to|for/item"
  end


  def test_parse_path_str_value
    assert_path ['path', ['to', 'foo'], 'item'], "path/to=foo/item"
    assert_path ['path', [nil, 'foo'], 'item'],  "path/*=foo/item"
    assert_path ['path', [nil, 'foo'], 'item'],  "path/=foo/item"

    assert_path ['path', ['to', /\A(foo|bar)\Z/], 'item'],
      "path/to=foo|bar/item"

    assert_path [/\A(path)\Z/i, [/\A(to)\Z/i, /\A(foo)\Z/i], /\A(item)\Z/i],
      "path/to=foo/item", Regexp::IGNORECASE
  end


  def test_parse_path_str_recur
    assert_path ['path', ['to', 'foo', true], 'item'],    "path/**/to=foo/item"
    assert_path [['path', nil, true], 'to', 'item'],      "**/**/path/to/item"
    assert_path ['path', 'to', 'item', [nil, nil, true]], "path/to/item/**/**"
    assert_path ['path', [nil, 'foo', true], 'item'],     "path/**=foo/item"
  end


  def test_parse_path_str_parent
    assert_path ['path', PARENT, 'item'],              "path/../item"
    assert_path ['path', [PARENT, 'foo'], 'item'],     "path/..=foo/item"
    assert_path ['path', [nil, 'foo', true], 'item'],  "path/**/..=foo/item"
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
  ANY_VALUE = Kronk::Path::ANY_VALUE

  def assert_path match, path, regexp_opt=nil
    match.map! do |i|
      i = [i] unless Array === i
      i[0] ||= ANY_VALUE
      i[1] ||= ANY_VALUE
      i[2] ||= false
      i
    end

    assert_equal match, Kronk::Path.parse_path_str(path, regexp_opt)
  end
end
