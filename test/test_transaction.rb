require 'test/test_helper'

class TestTransaction < Test::Unit::TestCase

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

    @trans = Kronk::Path::Transaction.new @data
  end


  def test_class_run
    block = lambda do |t|
      t.delete "key3/key*/2", "**=thing"
      t.select "**=foo*", "**/findme"
    end

    assert_equal @trans.run(&block),
      Kronk::Path::Transaction.run(@data, &block)

    assert_equal @trans.run(:keep_indicies => true, &block),
      Kronk::Path::Transaction.run(@data, :keep_indicies => true, &block)
  end


  def test_run
    expected = {
      :key1=>{:key1a=>["foo", "foobar", {}]},
      :key2=>"foobar",
      "findme"=>[123, 456, {:findme=>123456}]
    }

    result = @trans.run do |t|
      t.delete "key3/key*/2", "**=thing"
      t.select "**=foo*", "**/findme"
    end

    assert_equal expected, result
    assert_equal @data, @trans.run

    result2 = @trans.run do |t|
      t.delete "key3/key*/2", "**=thing"
      t.select "**=foo*", "**/findme"
    end

    assert_equal expected, result2
  end


  def test_results
    @trans.clear
    @trans.delete "key3/key*/2", "**=thing"
    @trans.select "**=foo*", "**/findme"
    result = @trans.results

    expected = {
      :key1=>{:key1a=>["foo", "foobar", {}]},
      :key2=>"foobar",
      "findme"=>[123, 456, {:findme=>123456}]
    }

    assert_equal expected, result
  end


  def test_results_keep_indicies
    @trans.clear
    @trans.delete "key3/key*/2", "**=thing"
    @trans.select "**=foo*", "**/findme"
    result = @trans.results :keep_indicies => true

    expected = {
      :key1=>{:key1a=>{2=>"foobar", 0=>"foo", 3=>{}}},
      :key2=>"foobar",
      "findme"=>[123, 456, {:findme=>123456}]
    }

    assert_equal expected, result
  end


  def test_remake_arrays_select
    result = @trans.transaction_select @data, "**=foo", "key3/key*/2"
    result = @trans.remake_arrays result

    expected = {:key1=>{:key1a=>["foo"]}, :key3=>{:key3a=>["val3"]}}

    assert_equal expected, result
  end


  def test_remake_arrays_select_except_modified
    result = @trans.transaction_select @data, "**=foo", "key3/key*/2"
    result = @trans.remake_arrays result, true

    expected = {:key1=>{:key1a=>{0=>"foo"}}, :key3=>{:key3a=>{2=>"val3"}}}

    assert_equal expected, result
  end


  def test_remake_arrays_select_root
    data_arr = @data.keys.sort{|x,y| x.to_s <=> y.to_s}.map{|k| @data[k]}

    @trans = Kronk::Path::Transaction.new data_arr
    result = @trans.transaction_select data_arr, "**=foo", "3/key*/2"
    result = @trans.remake_arrays result

    expected = [{:key1a=>["foo"]}, {:key3a=>["val3"]}]

    assert_equal expected, result
  end


  def test_remake_arrays_select_root_except_modified
    data_arr = @data.keys.sort{|x,y| x.to_s <=> y.to_s}.map{|k| @data[k]}

    @trans = Kronk::Path::Transaction.new data_arr
    result = @trans.transaction_select data_arr, "**=foo", "3/key*"
    result = @trans.remake_arrays result, true

    expected = {1=>{:key1a=>{0=>"foo"}}, 3=>{:key3a=>["val1", "val2", "val3"]}}

    assert_equal expected, result
  end


  def test_remake_arrays_delete
    result = @trans.transaction_delete @data, "**=foo", "key3/key*/2"
    result = @trans.remake_arrays result

    expected = {
      :key1 => {
        :key1a => ["bar", "foobar", {:findme => "thing"}],
        'key1b' => "findme"
      },
      'findme' => [123, 456, {:findme => 123456}],
      :key2 => "foobar",
      :key3 => {
        :key3a => ["val1", "val2"]
      }
    }

    assert_equal expected, result
  end


  def test_remake_arrays_delete_except_modified
    result = @trans.transaction_delete @data, "**=foo", "key3/key*/2"
    result = @trans.remake_arrays result, true

    expected = {
      :key1 => {
        :key1a => {1=>"bar", 2=>"foobar", 3=>{:findme=>"thing"}},
        'key1b' => "findme"
      },
      'findme' => [123, 456, {:findme => 123456}],
      :key2 => "foobar",
      :key3 => {
        :key3a => {0=>"val1", 1=>"val2"}
      }
    }

    assert_equal expected, result
  end


  def test_remake_arrays_delete_root
    data_arr = @data.keys.sort{|x,y| x.to_s <=> y.to_s}.map{|k| @data[k]}

    @trans = Kronk::Path::Transaction.new data_arr
    result = @trans.transaction_delete data_arr, "**=foo", "3/key*/2"
    result = @trans.remake_arrays result

    expected = [
      [123, 456, {:findme=>123456}],
      {:key1a=>["bar", "foobar", {:findme=>"thing"}], "key1b"=>"findme"},
      "foobar",
      {:key3a=>["val1", "val2"]}
    ]

    assert_equal expected, result
  end


  def test_remake_arrays_delete_root_except_modified
    data_arr = @data.keys.sort{|x,y| x.to_s <=> y.to_s}.map{|k| @data[k]}

    @trans = Kronk::Path::Transaction.new data_arr
    result = @trans.transaction_delete data_arr, "**=foo", "3/key*/2"
    result = @trans.remake_arrays result, true

    expected = [
      [123, 456, {:findme=>123456}],
      {:key1a=>{1=>"bar", 2=>"foobar", 3=>{:findme=>"thing"}},
      "key1b"=>"findme"},
      "foobar",
      {:key3a=>{0=>"val1", 1=>"val2"}}
    ]

    assert_equal expected, result
  end


  def test_transaction_select
    result = @trans.transaction_select @data, "**=foo", "key3/key*/2"
    expected = {:key1=>{:key1a=>{0=>"foo"}}, :key3=>{:key3a=>{2=>"val3"}}}

    assert_equal expected, result
  end


  def test_transaction_select_array
    data_arr = @data.keys.sort{|x,y| x.to_s <=> y.to_s}.map{|k| @data[k]}

    result = @trans.transaction_select data_arr, "**=foo", "3/key*/2"
    expected = {1=>{:key1a=>{0=>"foo"}}, 3=>{:key3a=>{2=>"val3"}}}

    assert_equal expected, result
  end


  def test_transaction_select_empty
    assert_equal @data, @trans.transaction_select(@data)
  end


  def test_transaction_delete
    result = @trans.transaction_delete @data, "**=foo", "key3/key*/2"
    expected = {
      :key1 => {
        :key1a => {1 => "bar", 2 => "foobar", 3 => {:findme => "thing"}},
        'key1b' => "findme"
      },
      'findme' => [123, 456, {:findme => 123456}],
      :key2 => "foobar",
      :key3 => {
        :key3a => {0 => "val1", 1 => "val2"}
      }
    }

    assert_equal expected, result
  end


  def test_transaction_delete_array
    data_arr = @data.keys.sort{|x,y| x.to_s <=> y.to_s}.map{|k| @data[k]}

    result = @trans.transaction_delete data_arr, "**=foo", "3/key*/2"
    expected = {
      0 => [123, 456, {:findme => 123456}],
      1 => {
        :key1a => {1 => "bar", 2 => "foobar", 3 => {:findme => "thing"}},
        'key1b' => "findme"
      },
      2 => "foobar",
      3 => {:key3a => {0 => "val1", 1 => "val2"}}
    }

    assert_equal expected, result
  end


  def test_transaction_delete_many_from_embedded_data
    result = @trans.transaction_delete @data, "key1/key1a/1", "key1/key1a/0"
    expected = {
      :key1a => {2 => "foobar", 3 => {:findme => "thing"}},
      'key1b' => "findme"
      }

    assert_equal expected, result[:key1]
  end


  def test_transaction_delete_empty
    assert_equal @data, @trans.transaction_delete(@data)
  end


  def test_transaction_move
    expected = {:key1=>{}, :key2=>"foobar",
      "mapped"=>{
        "1-a"=>["foo", "bar", "foobar", {}],
        "1-b"=>"findme", "3-a"=>["val1", "val2", "val3"]},
      :key3=>{}, "findme"=>[123, 456, {}],
      "more"=>{"one-findme"=>"thing", "two-findme"=>123456}}

    data = @trans.transaction_move @data, "key*/key??" => "mapped/%1-%3",
                                          "mapped"     => "remapped",
                                          "**=thing"   => "more/one-%1",
                                          "**=123456"  => "more/two-%1"
    data = @trans.remake_arrays data

    assert_equal expected, data
    assert_not_equal @data, data
  end


  def test_transaction_map
    expected = {
      "mapped"=>{
        "1-a"=>["foo", "bar", "foobar", {:findme=>"thing"}],
        "1-b"=>"findme", "3-a"=>["val1", "val2", "val3"]},
      "more"=>{:findme=>"thing"}
    }

    data = @trans.transaction_map @data, "key*/key??" => "mapped/%1-%3",
                                         "mapped"     => "remapped",
                                         "**=thing"   => "more/%1"

    assert_equal expected, data
    assert_not_equal @data, data
  end


  def test_transaction_move_array_conflicting
    expected = {:key1=>{:key1a=>[], "key1b"=>"findme"},:key2=>"foobar",
      :key3=>{:key3a=>[]}, "findme"=>[123, 456, {:findme=>123456}]}

    data = @trans.transaction_move @data, "key*/key??/*" => "mapped/%4"
    data = @trans.remake_arrays data

    mapped = data.delete "mapped"

    assert_equal expected, data
    assert_not_equal @data, data

    assert_equal({:findme=>"thing"}, mapped.last)

    # Due to unordered hashes, this could be
    # %w{val1 val2 val3} OR %w{foo bar foobar}
    assert_equal [String], mapped[0..2].map{|v| v.class}.uniq
  end


  def test_force_assign_paths
    data = {'foo' => 'bar'}

    new_data = @trans.force_assign_paths data,
                 %w{sub thing one}   => 'val1',
                 %w{sub thing two}   => 'val2',
                 ['sub', 'other', 3] => 'val3',
                 ['sub', 'other', 1] => 'val4',
                 ['sub', 'other', 5, 6] => 'val5'

    assert_equal({'foo' => 'bar'}, data)

    expected = {
      'foo' => 'bar',
      'sub' => {
        'thing' => {'one' => 'val1', 'two' => 'val2'},
        'other' => {3 => 'val3', 1 => 'val4', 5 => {6 => 'val5'}}
      }
    }
    assert_equal expected, new_data

    expected['sub']['other'] = ['val4', 'val3', ['val5']]
    new_data = @trans.remake_arrays new_data
    assert_equal expected, new_data
  end


  def test_force_assign_paths_root_array
    data = ['foo', 'bar']

    new_data = @trans.force_assign_paths data,
                 [1, 'thing', 'one'] => 'val1',
                 [1, 'thing', 'two'] => 'val2',
                 [3, 'other', 3]     => 'val3',
                 [3, 'other', 1]     => 'val4',
                 [3, 'other', 5, 6]  => 'val5'

    assert_equal(['foo', 'bar'], data)

    expected = {
      0 => 'foo',
      1 => {'thing' => {'one' => 'val1', 'two' => 'val2'}},
      3 => {'other' => {3 => 'val3', 1 => 'val4', 5 => {6 => 'val5'}}}
    }
    assert_equal expected, new_data

    expected[3]['other'] = ['val4', 'val3', ['val5']]
    new_data = @trans.remake_arrays new_data
    assert_equal expected, new_data
  end


  def test_ary_to_hash
    expected = {1 => :a, 0 => :foo, 2 => :b}
    assert_equal expected, @trans.ary_to_hash([:foo, :a, :b])
  end


  def test_hash_to_ary
    assert_equal [:foo, :a, :b], @trans.hash_to_ary(1 => :a, 0 => :foo, 2 => :b)
  end


  def test_clear
    @trans.delete "foo"
    @trans.select "bar"

    @trans.clear

    assert @trans.instance_variable_get(:@actions)[:delete].empty?
    assert @trans.instance_variable_get(:@actions)[:select].empty?
    assert @trans.instance_variable_get(:@make_array).empty?
  end


  def test_select
    @trans.select "path1", "path2", "path3"
    assert_equal ["path1", "path2", "path3"],
                 @trans.instance_variable_get(:@actions)[:select]

    @trans.select "path4", "path5"
    assert_equal ["path1", "path2", "path3", "path4", "path5"],
                 @trans.instance_variable_get(:@actions)[:select]
  end


  def test_delete
    @trans.delete "path1", "path2", "path3"
    assert_equal ["path1", "path2", "path3"],
                 @trans.instance_variable_get(:@actions)[:delete]

    @trans.delete "path4", "path5"
    assert_equal ["path1", "path2", "path3", "path4", "path5"],
                 @trans.instance_variable_get(:@actions)[:delete]
  end
end
