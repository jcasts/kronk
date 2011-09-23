require 'test/test_helper'

class TestDataString < Test::Unit::TestCase

  def setup
    @dstr = Kronk::DataString.new
    @dstr.append "foobar", "data0"
  end


  def test_new
    expected_meta = ["data0"] * @dstr.length
    assert_equal expected_meta, @dstr.meta
  end


  def test_append
    @dstr.append "\nthingz", "data1"
    expected_meta = (["data0"] * 6) + (["data1"] * 7)
    assert_equal expected_meta, @dstr.meta
  end


  def test_insert
    @dstr << "\nthingz"
    expected_meta = ["data0"] * 13
    assert_equal expected_meta, @dstr.meta
  end


  def test_select
    @dstr.append "\nthingz", "data1"
    new_dstr      = @dstr[4..9]
    expected_meta = (["data0"] * 2) + (["data1"] * 4)
    assert_equal expected_meta, new_dstr.meta
  end


  def test_split
    @dstr.append "\nthingz", "data1"
    arr = @dstr.split

    expected = ["data0"] * 6
    assert_equal expected, arr.first.meta

    expected = ["data1"] * 6
    assert_equal expected, arr.last.meta
  end


  def test_split_chars
    @dstr.append "\nthingz", "data1"
    arr = @dstr.split ''

    arr.each_with_index do |dstr, i|
      assert_equal [@dstr.meta[i]], dstr.meta
    end
  end


  def test_ordered_data_string_json
    expected = <<STR
{
 "acks": [
  [
   56,
   78
  ],
  [
   "12",
   "34"
  ]
 ],
 "root": [
  [
   "B1",
   "B2"
  ],
  [
   "A1",
   "A2"
  ],
  [
   "C1",
   "C2",
   [
    "C3a",
    "C3b"
   ]
  ],
  {
   ":tests": [
    "D3a",
    "D3b"
   ],
   "test": [
    [
     "D1a\\nContent goes here",
     "D1b"
    ],
    "D2"
   ]
  }
 ],
 "subs": [
  "a",
  "b"
 ],
 "tests": {
  ":foo": ":bar",
  "test": [
   [
    1,
    2
   ],
   2.123
  ]
 }
}
STR

    assert_equal expected.strip, Kronk::DataString.new(mock_data)
  end


  def test_ordered_data_string_struct_json
    expected = <<STR
{
 "acks": [
  [
   "Fixnum",
   "Fixnum"
  ],
  [
   "String",
   "String"
  ]
 ],
 "root": [
  [
   "String",
   "String"
  ],
  [
   "String",
   "String"
  ],
  [
   "String",
   "String",
   [
    "String",
    "String"
   ]
  ],
  {
   ":tests": [
    "String",
    "String"
   ],
   "test": [
    [
     "String",
     "String"
    ],
    "String"
   ]
  }
 ],
 "subs": [
  "String",
  "String"
 ],
 "tests": {
  ":foo": "Symbol",
  "test": [
   [
    "Fixnum",
    "Fixnum"
   ],
   "Float"
  ]
 }
}
STR

    assert_equal expected.strip,
                  Kronk::DataString.new(mock_data, :struct => true)

      assert_equal Kronk::DataString.json(mock_data, :struct => true),
                   Kronk::DataString.new(mock_data, :struct => true)
  end


  def test_ordered_data_string_ruby_paths
    with_config :render_lang => 'ruby', :render_paths => true do
      expected = <<STR
{
 "/acks/0/0" => 56,
 "/acks/0/1" => 78,
 "/acks/1/0" => "12",
 "/acks/1/1" => "34",
 "/root/0/0" => "B1",
 "/root/0/1" => "B2",
 "/root/1/0" => "A1",
 "/root/1/1" => "A2",
 "/root/2/0" => "C1",
 "/root/2/1" => "C2",
 "/root/2/2/0" => "C3a",
 "/root/2/2/1" => "C3b",
 "/root/3/test/0/0" => "D1a\\nContent goes here",
 "/root/3/test/0/1" => "D1b",
 "/root/3/test/1" => "D2",
 "/root/3/tests/0" => "D3a",
 "/root/3/tests/1" => "D3b",
 "/subs/0" => "a",
 "/subs/1" => "b",
 "/tests/foo" => :bar,
 "/tests/test/0/0" => 1,
 "/tests/test/0/1" => 2,
 "/tests/test/1" => 2.123
}
STR

      assert_equal expected.strip, Kronk::DataString.new(mock_data)
    end
  end


  def test_ordered_data_string_struct_ruby
    with_config :render_lang => 'ruby' do
      expected = <<STR
{
 "acks" => [
  [
   Fixnum,
   Fixnum
  ],
  [
   String,
   String
  ]
 ],
 "root" => [
  [
   String,
   String
  ],
  [
   String,
   String
  ],
  [
   String,
   String,
   [
    String,
    String
   ]
  ],
  {
   :tests => [
    String,
    String
   ],
   "test" => [
    [
     String,
     String
    ],
    String
   ]
  }
 ],
 "subs" => [
  String,
  String
 ],
 "tests" => {
  :foo => Symbol,
  "test" => [
   [
    Fixnum,
    Fixnum
   ],
   Float
  ]
 }
}
STR

      assert_equal expected.strip,
                    Kronk::DataString.new(mock_data, :struct => true)

      assert_equal Kronk::DataString.ruby(mock_data, :struct => true),
                   Kronk::DataString.new(mock_data, :struct => true)
    end
  end
end
