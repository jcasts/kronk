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
    expected = [{'content-disposition' => 'form-data; name="foo"'}, "bar"]
    assert_equal expected, @multi.parts.last
  end


  def test_add_headers
    @multi.add "foo", "bar", "X-Header" => "blah"
    expected = [{'content-disposition' => 'form-data; name="foo"',
      "X-Header" => "blah"}, "bar"]
    assert_equal expected, @multi.parts.last
  end


  def test_add_file
    file = File.open("test/mocks/200_response.json", "rb")
    @multi.add "foo", file

    expected = [{
      "content-disposition"       =>
        'form-data; name="foo"; filename="200_response.json"',
      "Content-Type"              => "application/json",
      "Content-Transfer-Encoding" => "binary"
    }, file]

    assert_equal expected, @multi.parts.last
  end


  def test_add_io
    prd, = IO.pipe
    @multi.add "foo", prd

    expected = [{
      "content-disposition"       => 'form-data; name="foo"',
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
    @multi.add "key1", "bar"
    @multi.add "key2", "some value"
    @multi.add "key3", "other thing"

    io = @multi.to_io
    assert_equal Kronk::MultipartIO, io.class
    assert_equal 1, io.parts.length
    assert_equal StringIO, io.parts.first.class

    expected = <<-STR
--foobar\r
content-disposition: form-data; name="key1"\r
\r
bar\r
--foobar\r
content-disposition: form-data; name="key2"\r
\r
some value\r
--foobar\r
content-disposition: form-data; name="key3"\r
\r
other thing\r
--foobar--
STR
    assert_equal expected.strip, io.read
  end


  def test_to_io_with_file
    file = File.open("test/mocks/200_response.json", "rb")
    @multi.add "key1", "bar"
    @multi.add "key2", "some value"
    @multi.add "my_file", file

    io = @multi.to_io
    assert_equal 3, io.parts.length
    assert_equal StringIO, io.parts.first.class
    assert_equal file, io.parts[1]
    assert_equal StringIO, io.parts.last.class

    file_content = File.read("test/mocks/200_response.json")

    head = <<-STR
--foobar\r
content-disposition: form-data; name="key1"\r
\r
bar\r
--foobar\r
content-disposition: form-data; name="key2"\r
\r
some value\r
--foobar\r
content-disposition: form-data; name="my_file"; filename="200_response.json"\r
    STR

    ctype_line = "Content-Type: application/json\r\n"
    ctran_line = "Content-Transfer-Encoding: binary\r\n"
    tail       = "\r\n#{file_content}\r\n--foobar--"

    output = io.read head.bytes.count
    assert_equal head, output

    output = ""
    output << io.read(1) while output[-1..-1] != "\n"

    comp1, comp2 = output.length == ctype_line.length ?
      [ctype_line, ctran_line] : [ctran_line, ctype_line]

    assert_equal comp1, output

    output = ""
    output << io.read(1) while output[-1..-1] != "\n"

    assert_equal comp2, output

    assert_equal tail, io.read
  end
end
