require 'test/test_helper'
require 'lib/kronk/test/assertions'

class TestAssertions < Test::Unit::TestCase
  include Kronk::Test::Assertions

  def setup
    @array = [:a, :b, {:foo => "bar", :bar => [:a, :b, {:foo => "other"}]}, :c]
    @hash  = {:foo => "bar", :bar => [:a, :b, {:foo => "other"}], :a => [1,2,3]}
  end


  def test_assert_data_at
    assert_data_at @array, "2/bar/2"
    assert_data_at @hash, "bar/2"
  end


  def test_assert_data_at_failure
    self.expects(:assert).with(false, "OOPS")
    assert_data_at @array, "foobar", "OOPS"
  end


  def test_assert_no_data_at
    assert_no_data_at @array, "foobar"
  end


  def test_assert_no_data_at_failure
    self.expects(:assert).with(false, "OOPS")
    assert_no_data_at @array, "**/foo", "OOPS"
  end


  def test_assert_data_at_equal
    assert_data_at_equal @array, "2/bar/2/foo", "other"
    assert_data_at_equal @hash, "bar/2/foo", "other"
  end


  def test_assert_data_at_equal_failure
    self.expects(:assert).with(false, "OOPS")
    self.expects(:assert_equal).with("nodice", nil, "OOPS")
    assert_data_at_equal @array, "foobar", "nodice", "OOPS"
  end


  def test_assert_data_at_not_equal
    assert_data_at_not_equal @array, "foobar", "thing"
  end


  def test_assert_data_at_not_equal_failure
    self.expects(:assert_not_equal).with("bar", "bar", "OOPS")
    assert_data_at_not_equal @array, "**/foo", "bar", "OOPS"
  end


  def test_assert_equal_responses
    io        = StringIO.new mock_resp("200_response.json")
    mock_resp = Kronk::Response.new io

    Kronk.expects(:request).times(2).
      with("host.com", :foo => "bar").returns mock_resp

    assert_equal_responses "host.com", "host.com", :foo => "bar"
  end


  def test_assert_equal_responses_failure
    mock_resp1 = Kronk::Response.new \
                  StringIO.new mock_resp("200_response.json")

    mock_resp2 = Kronk::Response.new \
                  StringIO.new mock_resp("301_response.txt")

    Kronk.expects(:request).
      with("host1.com", :foo => "bar").returns mock_resp1

    Kronk.expects(:request).
      with("host2.com", :foo => "bar").returns mock_resp2

    left  = Kronk::DataString.new mock_resp1.data
    right = mock_resp2.body

    assert_not_equal left, right

    self.expects(:assert_equal).with left, right

    assert_equal_responses "host1.com", "host2.com", :foo => "bar"
  end
end
