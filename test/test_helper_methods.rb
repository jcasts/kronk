require 'test/test_helper'
require 'lib/kronk/test/helper_methods'

class TestHelperMethods < Test::Unit::TestCase
  include Kronk::Test::HelperMethods

  def setup
    io          = StringIO.new mock_resp("200_response.json")
    @json       = JSON.parse mock_resp("200_response.json").split("\r\n\r\n")[1]
    @mock_resp  = Kronk::Response.new io
    @mock_resp2 = Kronk::Response.new \
                    StringIO.new mock_resp("200_response.json")
    @mock_req   = stub("mock_req", :retrieve => @mock_resp,  :uri => "host.com")
    @mock_req2  = stub("mock_req", :retrieve => @mock_resp2, :uri => "host.com")

    @mock_thread = stub("mock_thread", :join => nil)

    Thread.stubs(:new).yields.returns @mock_thread
    Kronk::Request.any_instance.stubs(:new).returns @mock_req
  end


  def test_get
    Kronk::Request.expects(:new).
      with("host.com", :foo => "bar", :http_method => :get).
      returns @mock_req

    get "host.com", :foo => "bar", :http_method => :foobar
  end


  def test_get_two
    Kronk::Request.expects(:new).times(2).
      with("host.com", :foo => "bar", :http_method => :get).
      returns @mock_req

    get "host.com", "host.com", :foo => "bar", :http_method => :foobar
  end


  def test_post
   Kronk::Request.expects(:new).
      with("host.com", :foo => "bar", :http_method => :post).
      returns @mock_req

    post "host.com", :foo => "bar", :http_method => :foobar
  end


  def test_post_two
    Kronk::Request.expects(:new).times(2).
      with("host.com", :foo => "bar", :http_method => :post).
      returns @mock_req

    post "host.com", "host.com", :foo => "bar", :http_method => :foobar
  end


  def test_put
    Kronk::Request.expects(:new).
      with("host.com", :foo => "bar", :http_method => :put).
      returns @mock_req

    put "host.com", :foo => "bar", :http_method => :foobar
  end


  def test_put_two
    Kronk::Request.expects(:new).times(2).
      with("host.com", :foo => "bar", :http_method => :put).
      returns @mock_req

    put "host.com", "host.com", :foo => "bar", :http_method => :foobar
  end



  def test_delete
   Kronk::Request.expects(:new).
      with("host.com", :foo => "bar", :http_method => :delete).
      returns @mock_req

    delete "host.com", :foo => "bar", :http_method => :foobar
  end


  def test_delete_two
    Kronk::Request.expects(:new).times(2).
      with("host.com", :foo => "bar", :http_method => :delete).
      returns @mock_req

    delete "host.com", "host.com", :foo => "bar", :http_method => :foobar
  end


  def test_retrieve_one
    Kronk::Request.expects(:new).
      with("host.com", :foo => "bar", :test => "thing").returns @mock_req

    @mock_resp.expects(:selective_data).with(:foo => "bar", :test => "thing").
      returns @json

    retrieve "host.com", {:foo => "bar"}, :test => "thing"

    assert_equal @mock_resp, @response
    assert_equal [@mock_resp], @responses

    assert_equal @json, @data
    assert_equal [@json], @datas

    assert_nil @diff
  end


  def test_retrieve_two
    Kronk::Request.expects(:new).
      with("host1.com", :foo => "bar").returns @mock_req

    Kronk::Request.expects(:new).
      with("host2.com", :foo => "bar").returns @mock_req2

    @mock_resp.expects(:selective_data).twice.with(:foo => "bar").returns @json
    @mock_resp2.expects(:selective_data).twice.with(:foo => "bar").returns @json

    retrieve "host1.com", "host2.com", :foo => "bar"

    assert_equal @mock_resp2, @response
    assert_equal [@mock_resp, @mock_resp2], @responses

    assert_equal @json, @data
    assert_equal [@json, @json], @datas

    expected_diff = Kronk::Diff.new_from_data(*@datas)

    assert_equal expected_diff.str1, @diff.str1
    assert_equal expected_diff.str2, @diff.str2
  end


  def test_retrieve_unparsable
    mock_resp = Kronk::Response.new StringIO.new(mock_200_response)
    mock_req  = stub("mock_req", :retrieve => mock_resp, :uri => "host.com")

    Kronk::Request.expects(:new).
      with("host.com", :foo => "bar").returns mock_req

    retrieve "host.com", :foo => "bar"

    assert_equal mock_resp, @response
    assert_equal [mock_resp], @responses

    assert_equal mock_resp.body, @data
    assert_equal [mock_resp.body], @datas

    assert_nil @diff
  end


  def test_retrieve_two_unparsable
    mock_resp = Kronk::Response.new StringIO.new(mock_200_response)

    Kronk::Request.any_instance.expects(:retrieve).returns mock_resp
    Kronk::Request.any_instance.expects(:retrieve).returns mock_resp

    retrieve "host1.com", "host2.com", :foo => "bar"

    assert_equal mock_resp, @response
    assert_equal [mock_resp, mock_resp], @responses

    assert_equal mock_resp.body, @data
    assert_equal [mock_resp.body, mock_resp.body], @datas

    expected_diff = Kronk::Diff.new(*@datas)

    assert_equal expected_diff.str1, @diff.str1
    assert_equal expected_diff.str2, @diff.str2
  end
end
