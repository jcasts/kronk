require 'test/test_helper'

class TestMultipart < Test::Unit::TestCase

  def setup
    @multi = Kronk::Multipart.new "foobar"
  end


  def test_initialize
    assert_equal "foobar", @multi.boundary
  end


  def test_add
    @multi.add "foo", "bar"
    expected = [{'content-disposition' => 'form-data; name=foo'}, "bar"]
    assert_equal expected, @multi.parts.last
  end


  def test_add_headers
    @multi.add "foo", "bar", "X-Header" => "blah"
    expected = [{'content-disposition' => 'form-data; name=foo',
      "X-Header" => "blah"}, "bar"]
    assert_equal expected, @multi.parts.last
  end


  def test_add_file
    file = File.open("test/mocks/200_response.json", "rb")
    @multi.add "foo", file

    expected = [{
      "content-disposition"       => 'form-data; name=foo; filename=200_response.json',
      "Content-Type"              => "application/json",
      "Content-Transfer-Encoding" => "binary"
    }, file]

    assert_equal expected, @multi.parts.last
  end


  def test_add_io
    prd, pwr = IO.pipe
    @multi.add "foo", prd

    expected = [{
      "content-disposition"       => 'form-data; name=foo',
      "Content-Type"              => "application/octet-stream",
      "Content-Transfer-Encoding" => "binary"
    }, prd]

    assert_equal expected, @multi.parts.last
  end


  def test_add_escaped_name
    @multi.add "foo:10", "bar"
    expected = [{'content-disposition' => 'form-data; name="foo:10"'}, "bar"]
    assert_equal expected, @multi.parts.last
  end


  def test_to_io
    
  end
end
