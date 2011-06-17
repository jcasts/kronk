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
      :key2 => "foobar",
      :key3 => {
        :key3a => ["val1", "val2", "val3"]
      }
    }

    @dataset = Kronk::DataSet.new @data

    @dataset_mock = Kronk::DataSet.new mock_data
  end


  def test_modify_only_data
    data = @dataset_mock.modify :only_data => "subs/1"
    assert_equal({"subs" => [nil, "b"]}, data)
  end


  def test_modify_ignore_data
    data = @dataset_mock.modify :ignore_data => "subs/1"

    expected = mock_data
    expected['subs'].delete_at 1

    assert_equal expected, data
  end


  def test_modify_only_data_with
    data = @dataset_mock.modify :only_data_with => "subs/1"
    assert_equal({"subs" => ["a", "b"]}, data)
  end


  def test_modify_only_and_ignored_data
    data = @dataset_mock.modify :ignore_data => "subs/1", :only_data => "subs/1"
    assert_equal({"subs" => [nil]}, data)
  end


  def test_collect_data_points_affect_parent_array
    data = @dataset_mock.collect_data_points "**=(A|a)?", true

    expected = {
      "root" => [nil, ["A1", "A2"]],
      "subs" => ["a", "b"]
    }

    assert_equal expected, data
  end


  def test_collect_data_points_affect_parent_hash
    data = @dataset_mock.collect_data_points "**=bar?", true
    assert_equal({"tests"=>{:foo=>:bar, "test"=>[[1, 2], 2.123]}}, data)
  end


  def test_collect_data_points_single
    data = @dataset_mock.collect_data_points "subs/1"
    assert_equal({"subs" => [nil, "b"]}, data)
  end


  def test_collect_data_points_single_wildcard
    data = @dataset_mock.collect_data_points "root/*/tests"
    assert_equal({"root"=>[nil, nil, nil, {:tests=>["D3a", "D3b"]}]}, data)
  end


  def test_collect_data_points_recursive_wildcard
    data = @dataset_mock.collect_data_points "**/test?"

    expected = {
      "tests"=>{:foo=>:bar, "test"=>[[1, 2], 2.123]},
      "root"=>[nil, nil, nil, {
        :tests=>["D3a", "D3b"],
        "test"=>[["D1a\nContent goes here", "D1b"], "D2"]}]
    }

    assert_equal expected, data
  end


  def test_collect_data_points_recursive_wildcard_value
    data = @dataset_mock.collect_data_points "**=(A|a)?"

    expected = {
      "root" => [nil, ["A1", "A2"]],
      "subs" => ["a"]
    }

    assert_equal expected, data
  end


  def test_delete_data_points_affect_parent_array
    data = @dataset_mock.delete_data_points "**/test/0/*", true

    expected = mock_data
    expected['root'][3]['test'].delete_at 0
    expected['tests']['test'].delete_at 0

    assert_equal expected, data
  end


  def test_delete_data_points_affect_parent_array_value
    data = @dataset_mock.delete_data_points "**/test/0/*=D*", true

    expected = mock_data
    expected['root'][3]['test'].delete_at 0

    assert_equal expected, data
  end


  def test_delete_data_points_affect_parent_hash
    data = @dataset_mock.delete_data_points "subs/1", true

    expected = mock_data
    expected.delete 'subs'

    assert_equal expected, data
  end


  def test_delete_data_points_affect_parent_hash_value
    data = @dataset_mock.delete_data_points "**/*=a", true

    expected = mock_data
    expected.delete 'subs'

    assert_equal expected, data
  end


  def test_delete_data_points_single
    data = @dataset_mock.delete_data_points "subs/1"

    expected = mock_data
    expected['subs'].delete_at 1

    assert_equal expected, data
  end


  def test_delete_data_points_single_wildcard
    data = @dataset_mock.delete_data_points "root/*/tests"

    expected = mock_data
    expected['root'][3].delete :tests

    assert_equal expected, data
  end


  def test_delete_data_points_single_wildcard_qmark
    data = @dataset_mock.delete_data_points "subs/?"

    expected = mock_data
    expected['subs'].clear

    assert_equal expected, data
  end


  def test_delete_data_points_recursive_wildcard
    data = @dataset_mock.delete_data_points "**/test?"

    expected = mock_data
    expected['root'][3].delete :tests
    expected['root'][3].delete 'test'
    expected.delete "tests"

    assert_equal expected, data
  end


  def test_delete_data_points_recursive_wildcard_value
    data = @dataset_mock.delete_data_points "**=A?|a?"

    expected = mock_data
    expected['root'][1].clear
    expected['subs'] = ["b"]

    assert_equal expected, data
  end


  def test_yield_data_points
    keys = []

    @dataset.yield_data_points @data, /key/ do |data, key|
      keys << key.to_s
      assert_equal @data, data
    end

    assert_equal ['key1', 'key2', 'key3'], keys.sort
  end


  def test_yield_data_points_recursive
    keys = []
    data_points = []

    @dataset.yield_data_points @data, :findme, nil, true do |data, key|
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

    @dataset.yield_data_points @data, nil, "findme" do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert keys.empty?
    assert data_points.empty?

    @dataset.yield_data_points @data, nil, "findme", true do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert_equal ['key1b'], keys
    assert_equal [@data[:key1]], data_points
  end


  def test_hash_each_data_item
    hash = {
      :a => 1,
      :b => 2,
      :c => 3
    }

    keys = []
    values = []

    @dataset.each_data_item hash do |key, val|
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

    @dataset.each_data_item ary do |key, val|
      keys << key
      values << val
    end

    assert_equal [0,1,2], keys
    assert_equal ary, values
  end
end
