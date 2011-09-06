require 'test/test_helper'

class TestDataString < Test::Unit::TestCase

  def setup
    @dstr = Kronk::DataString.new "foobar", "data0"
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
end
