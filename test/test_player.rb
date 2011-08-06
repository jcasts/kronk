require 'test/test_helper'

class TestPlayer < Test::Unit::TestCase

  def setup
    @out, @inn = IO.pipe
    @player    = Kronk::Player.new :io => @out
  end


  def test_init
    assert_equal Kronk::Player::InputReader,   @player.input.class
    assert_equal Kronk::Player::RequestParser, @player.input.parser
    assert_equal Kronk::Player::Suite,         @player.output.class
    assert_equal Mutex,                        @player.mutex.class
    assert_equal @out,                         @player.input.io
    assert_equal 1,                            @player.concurrency
    assert_nil                                 @player.number
    assert                                     @player.queue.empty?
    assert                                     @player.threads.empty?
  end


  def test_init_opts
    player = Kronk::Player.new :number      => 1000,
                               :concurrency => 10,
                               :output      => :stream

    assert_equal Kronk::Player::Stream, player.output.class
    assert_equal 10,                    player.concurrency
    assert_equal 1000,                  player.number
  end


  def test_output
    @player.output = :benchmark
    assert_equal Kronk::Player::Benchmark, @player.output.class

    @player.output = :stream
    assert_equal Kronk::Player::Stream, @player.output.class

    @player.output = :suite
    assert_equal Kronk::Player::Suite, @player.output.class

    @player.output = Kronk::Player::Benchmark
    assert_equal Kronk::Player::Benchmark, @player.output.class
  end


  def test_queue_req
    @player.queue_req :first_item
    @player.queue_req :second_item
    assert_equal [:first_item, :second_item], @player.queue
  end


  def test_from_io
    @player.from_io "mock"
    assert_equal "mock", @player.input.io
    assert_equal Kronk::Player::RequestParser, @player.input.parser

    @player.from_io "mock", "mock_parser"
    assert_equal "mock", @player.input.io
    assert_equal "mock_parser", @player.input.parser
  end
end
