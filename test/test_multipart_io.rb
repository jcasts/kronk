require 'test/test_helper'

class TestMultipartIo < Test::Unit::TestCase

  def setup
    strio = StringIO.new "thing"
    @io   = Kronk::MultipartIO.new "foo", "bar", strio

    @pipe_rd, @pipe_wr = IO.pipe
    @pipe_wr.write "thing"
    @pipe_wr.close
    @pio  = Kronk::MultipartIO.new "foo", @pipe_rd, "bar"

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


  def test_read_all_strings
    assert_equal "foobarthing", @io.read_all
    assert_nil @io.read 1
    assert_equal "", @io.read
  end


  def test_read_all_file
    assert_equal "foo#{File.read "test/mocks/200_response.json"}bar",
                 @fio.read_all
    assert_nil @fio.read 1
    assert_equal "", @fio.read
  end


  def test_read_all_io
    assert_equal "foothingbar",
                 @pio.read_all
    assert_nil @pio.read 1
    assert_equal "", @pio.read
  end


  def test_read_all_after_read_partial
    assert_equal "foo", @pio.read(3)
    assert_equal "thingbar", @pio.read
  end


  def test_eof
    assert !@pio.eof?, "EOF should NOT be reached"
    @pio.read 5

    assert !@pio.eof?, "EOF should NOT be reached"
    @pio.read_all

    assert @pio.eof?, "EOF should be reached"
  end


  def test_close
    @pio.parts.each do |io|
      assert !io.closed?, "#{io.inspect} should NOT be closed"
    end

    @pio.close

    @pio.parts.each do |io|
      assert io.closed?, "#{io.inspect} should be closed"
    end
  end
end
