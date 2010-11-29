require 'test/test_helper'

class TestDataSet < Test::Unit::TestCase


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
      :key2 => "foobar"
    }

    @dataset = Kronk::DataSet.new @data
  end


  def test_find_data_recursive
    keys = []
    data_points = []

    @dataset.find_data "**/findme" do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert_equal 3, keys.length
    assert_equal 1, keys.uniq.length
    assert_equal "findme", keys.first

    assert data_points.include?(@data)
    assert data_points.include?(@data[:key1][:key1a].last)
    assert data_points.include?(@data['findme'].last)
  end


  def test_parse_data_path
    data_path = "key1/key\\/2=value/key*=*value/**=value2/key\\=thing"
    key, value, rec, data_path = Kronk::DataSet.parse_data_path data_path

    assert_equal "key1", key
    assert_nil value
    assert !rec, "Should not return recursive = true"
    assert_equal "key\\/2=value/key*=*value/**=value2/key\\=thing", data_path
  end


  def test_parse_data_path_escaped_slash
    key, value, rec, data_path =
      Kronk::DataSet.parse_data_path \
        "key\\/2=value/key*=*value/**=value2/key\\=thing"

    assert_equal "key/2", key
    assert_equal "value", value
    assert !rec, "Should not return recursive = true"
    assert_equal "key*=*value/**=value2/key\\=thing", data_path
  end


  def test_parse_data_path_recursive_value
    key, value, rec, data_path =
      Kronk::DataSet.parse_data_path "**=value2/key\\=thing"

    assert_equal /.*/, key
    assert_equal "value2", value
    assert rec, "Should return recursive = true"
    assert_equal "key\\=thing", data_path
  end


  def test_parse_data_path_recursive
    data_path = "**"
    key, value, rec, data_path = Kronk::DataSet.parse_data_path "**"

    assert_equal /.*/, key
    assert_nil value
    assert rec, "Should return recursive = true"
    assert_nil data_path
  end


  def test_parse_data_path_recursive_key
    data_path = "**"
    key, value, rec, data_path = Kronk::DataSet.parse_data_path "**/key"

    assert_equal "key", key
    assert_nil value
    assert rec, "Should return recursive = true"
    assert_nil data_path
  end


  def test_parse_data_path_escaped_equal
    key, value, rec, data_path = Kronk::DataSet.parse_data_path "key\\=thing"

    assert_equal "key=thing", key
    assert_nil value
    assert !rec, "Should not return recursive = true"
    assert_equal nil, data_path
  end


  def test_parse_data_path_last
    key, value, rec, data_path = Kronk::DataSet.parse_data_path "key*"

    assert_equal /key.*/, key
    assert_nil value
    assert !rec, "Should not return recursive = true"
    assert_equal nil, data_path
  end


  def test_parse_data_path_empty
    key, value, rec, data_path = Kronk::DataSet.parse_data_path ""

    assert_equal nil, key
    assert_nil value
    assert !rec, "Should not return recursive = true"
    assert_equal nil, data_path
  end


  def test_parse_path_item
    assert_equal "foo", Kronk::DataSet.parse_path_item("foo")

    assert_equal /foo.*bar/, Kronk::DataSet.parse_path_item("foo*bar")
    assert_equal /foo|bar/, Kronk::DataSet.parse_path_item("foo|bar")
    assert_equal /foo.?bar/, Kronk::DataSet.parse_path_item("foo?bar")

    assert_equal /foo.?\?bar/, Kronk::DataSet.parse_path_item("foo?\\?bar")
    assert_equal /key.*/, Kronk::DataSet.parse_path_item("key*")

    assert_equal "foo*bar", Kronk::DataSet.parse_path_item("foo\\*bar")
    assert_equal "foo|bar", Kronk::DataSet.parse_path_item("foo\\|bar")
    assert_equal "foo?bar", Kronk::DataSet.parse_path_item("foo\\?bar")
  end


  def test_yield_data_points
    keys = []

    Kronk::DataSet.yield_data_points @data, /key/ do |data, key|
      keys << key.to_s
      assert_equal @data, data
    end

    assert_equal ['key1', 'key2'], keys.sort
  end


  def test_yield_data_points_recursive
    keys = []
    data_points = []

    Kronk::DataSet.yield_data_points @data, :findme, nil, true do |data, key|
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


  def test_yield_data_points_value
    keys = []
    data_points = []

    Kronk::DataSet.yield_data_points @data, nil, "findme" do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert keys.empty?
    assert data_points.empty?

    Kronk::DataSet.yield_data_points @data, nil, "findme", true do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert_equal ['key1b'], keys
    assert_equal [@data[:key1]], data_points
  end


  def test_match_data_item
    assert Kronk::DataSet.match_data_item(:key, "key")
    assert Kronk::DataSet.match_data_item("key", :key)

    assert Kronk::DataSet.match_data_item(/key/, "foo_key")
    assert !Kronk::DataSet.match_data_item("foo_key", /key/)

    assert Kronk::DataSet.match_data_item(nil, "foo_key")
    assert !Kronk::DataSet.match_data_item("foo_key", nil)
  end


  def test_hash_each_data_item
    hash = {
      :a => 1,
      :b => 2,
      :c => 3
    }

    keys = []
    values = []

    Kronk::DataSet.each_data_item hash do |key, val|
      keys << key
      values << val
    end

    assert_equal keys, (keys | hash.keys)
    assert_equal values, (values | hash.values)
  end


  def test_array_each_data_item
    ary = [:a, :b, :c]

    keys = []
    values = []

    Kronk::DataSet.each_data_item ary do |key, val|
      keys << key
      values << val
    end

    assert_equal [0,1,2], keys
    assert_equal ary, values
  end
end
