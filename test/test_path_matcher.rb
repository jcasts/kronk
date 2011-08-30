require 'test/test_helper'

class TestPathMatcher < Test::Unit::TestCase

  def setup
    @matcher = Kronk::Path::Matcher.new :key => "foo*", :value => "*bar*"
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


  def test_new
    assert_equal %r{\Afoo(.*)\Z},     @matcher.key
    assert_equal %r{\A(.*)bar(.*)\Z}, @matcher.value
    assert !@matcher.recursive?
  end



  def test_each_data_item_hash
    hash = {
      :a => 1,
      :b => 2,
      :c => 3
    }

    keys = []
    values = []

    @matcher.each_data_item hash do |key, val|
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

    @matcher.each_data_item ary do |key, val|
      keys << key
      values << val
    end

    assert_equal [2,1,0], keys
    assert_equal ary.reverse, values
  end


  def test_match_node
    assert @matcher.match_node(:key, "key")
    assert @matcher.match_node("key", :key)

    assert @matcher.match_node(/key/, "foo_key")
    assert !@matcher.match_node("foo_key", /key/)
    assert @matcher.match_node(/key/, /key/)

    assert @matcher.match_node(Kronk::Path::ANY_VALUE, "foo_key")
    assert !@matcher.match_node("foo_key", Kronk::Path::ANY_VALUE)

    assert @matcher.match_node(1..3, 1)
    assert !@matcher.match_node(1, 1..3)
    assert @matcher.match_node(1..3, 1..3)
  end


  def test_find_in
    keys = []

    Kronk::Path::Matcher.new(:key => /key/).find_in @data do |data, key|
      keys << key.to_s
      assert_equal @data, data
    end

    assert_equal ['key1', 'key2', 'key3'], keys.sort
  end


  def test_find_in_recursive
    keys = []
    data_points = []

    matcher = Kronk::Path::Matcher.new :key       => :findme,
                                       :recursive => true

    matcher.find_in @data do |data, key|
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


  def test_find_in_value
    keys = []
    data_points = []

    matcher = Kronk::Path::Matcher.new :key => "*", :value => "findme"
    matcher.find_in @data do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert keys.empty?
    assert data_points.empty?

    matcher = Kronk::Path::Matcher.new :key       => "*",
                                       :value     => "findme",
                                       :recursive => true

    matcher.find_in @data do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert_equal ['key1b'], keys
    assert_equal [@data[:key1]], data_points
  end


  def test_find_in_match
    matcher = Kronk::Path::Matcher.new :key       => "find*",
                                       :value     => "th*g",
                                       :recursive => true
    paths = matcher.find_in @data
    assert_equal [[:key1, :key1a, 3, :findme]], paths
    assert_equal Kronk::Path::PathMatch, paths.first.class

    assert_equal ["me", "in"], paths.first.matches
  end


  def test_find_in_match_one
    matcher = Kronk::Path::Matcher.new :key       => "findme|foo",
                                       :recursive => true
    paths = matcher.find_in @data

    expected_paths = [
      ["findme"],
      ["findme", 2, :findme],
      [:key1, :key1a, 3, :findme]
    ]

    assert_equal expected_paths, (expected_paths | paths)
    assert_equal Kronk::Path::PathMatch, paths.first.class

    assert_equal ["findme"], paths.first.matches
  end


  def test_find_in_match_one_value
    matcher = Kronk::Path::Matcher.new :key       => "findme|foo",
                                       :value     => "th*g",
                                       :recursive => true
    paths = matcher.find_in @data
    assert_equal [[:key1, :key1a, 3, :findme]], paths
    assert_equal Kronk::Path::PathMatch, paths.first.class

    assert_equal ["findme", "in"], paths.first.matches
  end


  def test_find_in_match_any
    matcher = Kronk::Path::Matcher.new :key => "*"
    paths = matcher.find_in @data

    expected_paths = [
      ["findme"],
      [:key1],
      [:key2],
      [:key3]
    ]

    assert_equal expected_paths, (expected_paths | paths)
    assert_equal Kronk::Path::PathMatch, paths.first.class
    assert_equal expected_paths, (expected_paths | paths.map{|p| p.matches})
  end


  def test_parse_node_range
    assert_equal 1..4,   @matcher.parse_node("1..4")
    assert_equal 1...4,  @matcher.parse_node("1...4")
    assert_equal "1..4", @matcher.parse_node("\\1..4")
    assert_equal "1..4", @matcher.parse_node("1\\..4")
    assert_equal "1..4", @matcher.parse_node("1.\\.4")
    assert_equal "1..4", @matcher.parse_node("1..\\4")
    assert_equal "1..4", @matcher.parse_node("1..4\\")
  end


  def test_parse_node_index_length
    assert_equal 2...6, @matcher.parse_node("2,4")
    assert_equal "2,4", @matcher.parse_node("\\2,4")
    assert_equal "2,4", @matcher.parse_node("2\\,4")
    assert_equal "2,4", @matcher.parse_node("2,\\4")
    assert_equal "2,4", @matcher.parse_node("2,4\\")
  end


  def test_parse_node_anyval
    assert_equal Kronk::Path::ANY_VALUE, @matcher.parse_node("*")
    assert_equal Kronk::Path::ANY_VALUE, @matcher.parse_node("")
    assert_equal Kronk::Path::ANY_VALUE, @matcher.parse_node("**?*?*?")
    assert_equal Kronk::Path::ANY_VALUE, @matcher.parse_node(nil)
  end


  def test_parse_node_regex
    assert_equal(/\Atest(.*)\Z/,       @matcher.parse_node("test*"))
    assert_equal(/\A(.?)test(.*)\Z/,   @matcher.parse_node("?test*"))
    assert_equal(/\A\?test(.*)\Z/,     @matcher.parse_node("\\?test*"))
    assert_equal(/\A(.?)test\*(.*)\Z/, @matcher.parse_node("?test\\**"))
    assert_equal(/\A(.?)test(.*)\Z/,   @matcher.parse_node("?test*?**??"))
    assert_equal(/\Aa|b\Z/,            @matcher.parse_node("a|b"))
    assert_equal(/\Aa|b(c|d)\Z/,       @matcher.parse_node("a|b(c|d)"))

    @matcher.regex_opts = Regexp::IGNORECASE
    assert_equal(/\Aa|b(c|d)\Z/i, @matcher.parse_node("a|b(c|d)"))
  end


  def test_parse_node_string
    assert_equal "a|b", @matcher.parse_node("a\\|b")
    assert_equal "a(b", @matcher.parse_node("a\\(b")
    assert_equal "a?b", @matcher.parse_node("a\\?b")
    assert_equal "a*b", @matcher.parse_node("a\\*b")
  end


  def test_parse_node_passthru
    assert_equal Kronk::Path::PARENT,
      @matcher.parse_node(Kronk::Path::PARENT)

    assert_equal :thing, @matcher.parse_node(:thing)
  end
end
