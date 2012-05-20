require 'test/test_helper'

class TestMultipartIo < Test::Unit::TestCase

  def setup
    strio = StringIO.new "thing"
    @io   = Kronk::MultipartIO.new "foo", "bar", strio

    pipe_in, pipe_out = IO.pipe
    @pio  = Kronk::MultipartIO.new "foo", pipe_out, "bar"

    @file = File.open 'test/mocks/200_response.json', "r"
    @fio  = Kronk::MultipartIO.new "foo", @file, "bar"
  end


  def teardown
    @file.close
  end


  def test_initialize
    assert_equal StringIO, @io.parts[0].class
    assert_equal "foo", @io.parts[0].read
    assert_equal StringIO, @io.parts[1].class
    assert_equal "bar", @io.parts[1].read
    assert_equal StringIO, @io.parts[2].class
    assert_equal "thing", @io.parts[2].read
  end


  def test_size
    assert_equal 11, @io.size
    assert_nil @pio.size
    assert_equal((@file.size + 6), @fio.size)
  end


  def test_read_all
    assert_equal "foobarthing", @io.read_all
    assert_nil @io.read 1
    assert_equal "foo#{File.read "test/mocks/200_response.json"}bar",
                 @fio.read_all
    assert_nil @fio.read 1
  end
end
