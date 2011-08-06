require 'test/test_helper'

class TestPlayer < Test::Unit::TestCase

  class MockOutput; end
  class MockParser; end

  def setup
    @out, @inn = IO.pipe
    @parser    = MockParser
    @output    = MockOutput
    @player    = Kronk::Player.new :io     => @out,
                                   :parser => @parser,
                                   :output => @output
  end


  def test_init_defaults
    player = Kronk::Player.new
    assert_equal Kronk::Player::Suite,       player.output.class
    assert_equal Kronk::Player::InputReader, player.input.class
    assert_equal Mutex,                      player.mutex.class
    assert_equal 1,                          player.concurrency
    assert_nil                               player.input.io
    assert_nil                               player.number
    assert                                   player.queue.empty?
    assert                                   player.threads.empty?
  end


  def test_init
    assert_equal Kronk::Player::InputReader,   @player.input.class
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

    assert_equal Kronk::Player::Stream,        player.output.class
    assert_equal Kronk::Player::RequestParser, player.input.parser
    assert_equal 10,                           player.concurrency
    assert_equal 1000,                         player.number
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
    assert_equal MockParser, @player.input.parser

    @player.from_io "mock", "mock_parser"
    assert_equal "mock", @player.input.io
    assert_equal "mock_parser", @player.input.parser
  end


  def test_output_results
    @player.output.expects(:completed).with().returns "FINISHED"
    assert_equal "FINISHED", @player.output_results
  end


  def test_finished_false
    @player.number = nil

    @player.queue.clear
    @player.count = 2
    @player.input.stubs(:eof?).returns false
    assert !@player.finished?

    @player.queue << "test"
    @player.count = 2
    @player.input.stubs(:eof?).returns true
    assert !@player.finished?

    @player.count = 0
    @player.queue.clear
    @player.input.stubs(:eof?).returns true
    assert !@player.finished?

    @player.queue << "test"
    @player.input.stubs(:eof?).returns true
    @player.count  = 5
    @player.number = 10
    assert !@player.finished?
  end


  def test_finished_true
    @player.number = 4
    @player.count  = 4
    assert @player.finished?

    @player.number = nil
    @player.count  = 1
    @player.queue.clear
    @player.input.stubs(:eof?).returns true
    assert @player.finished?

    @player.number = 10
    @player.count  = 1
    @player.queue.clear
    @player.input.stubs(:eof?).returns true
    assert @player.finished?
  end


  def test_next_request
    @player.input.expects(:get_next).returns "NEXT ITEM"
    assert_equal "NEXT ITEM", @player.next_request

    @player.input.expects(:get_next).returns nil
    @player.queue.concat ["FIRST ITEM", "QUEUE REPEAT"]
    assert_equal "QUEUE REPEAT", @player.next_request

    @player.input.expects(:get_next).returns nil
    @player.queue.clear
    assert_equal Hash.new, @player.next_request
  end


  def test_process_compare
#    resp1 = mock_resp("200_response.json")
#    resp2 = mock_resp("200_response.txt")

#    expect_request :get, "http://example.com/test", :returns => resp1
#    expect_request :get, "http://beta-example.com/test", :returns => resp2

#    @player.output.expects(:result) do |kronk, mutex|
#      assert_equal @player.mutex, mutex
#      assert_equal Kronk::Diff.new(resp1, resp2).formatted, kronk.diff.formatted
#    end

#    @player.process_compare "example.com", "beta-example.com",
#      :uri_suffix => "/test", :include_headers => true
  end
end
