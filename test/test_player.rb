require 'test/test_helper'

class TestPlayer < Test::Unit::TestCase

  class MockPipe < StringIO; end

  class MockOutput < Kronk::Player::Output
    attr_accessor :result_calls

    def initialize *args
      @result_calls = 0
      super
    end

    def result kronk, mutex
      mutex.synchronize do
        @result_calls += 1
      end
    end
  end

  class MockParser
    def self.parse str
      str
    end
  end


  def setup
    Kronk::Player.async = false

    @io        = MockPipe.new
    @parser    = MockParser
    @output    = MockOutput
    @player    = Kronk::Player.new :io     => @io,
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
    assert_equal @io,                          @player.input.io
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
    @player.output_from :benchmark
    assert_equal Kronk::Player::Benchmark, @player.output.class

    @player.output_from :stream
    assert_equal Kronk::Player::Stream, @player.output.class

    @player.output_from :suite
    assert_equal Kronk::Player::Suite, @player.output.class

    @player.output_from Kronk::Player::Benchmark
    assert_equal Kronk::Player::Benchmark, @player.output.class
  end


  def test_from_io
    @player.from_io "mock"
    assert_equal "mock", @player.input.io
    assert_equal MockParser, @player.input.parser

    @player.from_io "mock", "mock_parser"
    assert_equal "mock", @player.input.io
    assert_equal "mock_parser", @player.input.parser
  end


  def test_finished_false
    @player.number = nil

    @player.queue.clear
    @player.count = 2
    @player.reader_thread = "mock thread"
    @player.reader_thread.stubs(:alive?).returns true
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
    @player.reader_thread.stubs(:alive?).returns false
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
    @player.reader_thread = "mock thread"
    @player.reader_thread.expects(:alive?).returns false
    assert @player.finished?

    @player.count = 4
    @player.queue.clear
    @player.reader_thread = "mock thread"
    @player.reader_thread.expects(:alive?).returns false
    assert @player.finished?

    @player.number = 10
    @player.count  = 1
    @player.queue.clear
    @player.reader_thread = nil
    assert @player.finished?
  end


  def test_compare_single
    io1  = StringIO.new(mock_200_response)
    io2  = StringIO.new(mock_302_response)
    expect_compare_output mock_200_response, mock_302_response

    @player.compare io1, io2
  end


  def test_compare
    @player.output.expects :start
    @player.output.expects :completed

    @player.concurrency  = 3
    @player.input.parser = Kronk::Player::RequestParser
    @player.input.io << "/req3\n/req4\n/req5\n"
    @player.input.io.rewind
    @player.input.io.close_write

    @player.queue.concat [{:uri_suffix => "/req1"}, {:uri_suffix => "/req2"}]

    part1 = (1..2).map{|n| "/req#{n}"}
    part2 = (3..5).map{|n| "/req#{n}"}

    part1.each do |path|
      mock_requests "example.com", "beta-example.com",
        :uri_suffix => path,
        :query      => "foo=bar"
    end

    part2.each do |path|
      mock_requests "example.com", "beta-example.com",
        :uri_suffix  => path,
        :query       => "foo=bar"
    end

    @player.compare "example.com", "beta-example.com", :query => "foo=bar"

    assert_equal 5, @player.output.result_calls
  end


  def test_request_single
    io = StringIO.new(mock_200_response)
    expect_request_output mock_200_response

    @player.request io
  end


  def test_request
    @player.concurrency = 3

    paths = %w{/req3 /req4 /req5}

    @player.on :input do
      @player.stop_input! if paths.empty?
      {:uri_suffix => paths.shift}
    end

    @player.queue.concat [{:uri_suffix => "/req1"}, {:uri_suffix => "/req2"}]

    part1 = (1..2).map{|n| "/req#{n}"}
    part2 = (3..5).map{|n| "/req#{n}"}

    part1.each do |path|
      mock_requests "example.com",
        :uri_suffix  => path,
        :query       => "foo=bar"
    end

    part2.each do |path|
      mock_requests "example.com",
        :uri_suffix => path,
        :query      => "foo=bar"
    end

    result_calls = 0

    @player.request "example.com", :query => "foo=bar" do |kronk, err|
      result_calls += 1
    end

    assert_equal 5, result_calls
  end


  def test_run_interrupted
    @player.concurrency = 0

    @player.output.expects :start
    @player.output.expects :completed

    thread = Thread.new do
      @player.run do |item, mutex|
        sleep 0.1
      end
    end

    sleep 0.1
    assert_exit 2 do
      Process.kill 'INT', Process.pid
    end

  ensure
    thread.kill
  end


  def test_process_queue
    @player.concurrency = 10
    requests = (1..20).map{|n| "request #{n}"}
    @player.queue.concat requests.dup
    @player.input.io.close

    start     = Time.now
    processed = []

    @player.process_queue do |req|
      processed << req
      sleep 0.5
    end

    time_spent = (Time.now - start).to_i
    assert_equal 1, time_spent
    assert_equal 20, @player.count
    assert @player.queue.empty?, "Expected queue to be empty"

    processed.sort!{|r1, r2| r1.split.last.to_i <=> r2.split.last.to_i}
    assert_equal requests, processed
  end


  def test_process_queue_from_io
    @player.concurrency = 10
    @player.input.parser.stubs(:start_new?).returns true
    @player.input.parser.stubs(:start_new?).with("").returns false

    processed  = []
    start_time = 0
    time_spent = 0

    requests = (1..20).map{|n| "request #{n}\n"}
    @player.from_io StringIO.new(requests.join)

    start_time = Time.now
    @player.process_queue do |req|
      processed << req
      sleep 0.5
    end

    time_spent = (Time.now - start_time).to_i

    assert_equal 1,  time_spent
    assert_equal 20, @player.count
    assert @player.queue.empty?, "Expected queue to be empty"

    processed.sort! do |r1, r2|
      r1.split.last.strip.to_i <=> r2.split.last.strip.to_i
    end

    assert_equal requests, processed
  end


  def test_single_request_from_io
    @player.input.io = StringIO.new "mock request"
    @player.input.parser.stubs(:start_new?).returns true
    assert @player.single_request?, "Expected player to have one request"
  end


  def test_single_request_from_queue
    @player.input.io = nil
    assert @player.single_request?, "Expected player to have one request"
  end


  def test_not_single_request
    @player.input.io = nil
    @player.queue.concat Array.new(10, "mock request")
    assert !@player.single_request?, "Expected player to have many requests"

    @player.input.io = StringIO.new Array.new(5, "mock request").join("\n")
    @player.queue.clear
    @player.input.parser.expects(:start_new?).returns(true)

    assert !@player.single_request?, "Expected player to have many requests"
  end


  def test_start_input_from_input
    @player.input.stubs(:get_next).returns "mock_request"

    @player.concurrency = 5
    @player.number      = 20

    thread = @player.start_input!
    assert_equal Thread, thread.class

    sleep 0.2
    assert_equal Array.new(10, "mock_request"), @player.queue

    @player.queue.slice!(8)

    sleep 0.2
    assert_equal Array.new(10, "mock_request"), @player.queue

  ensure
    thread.kill
  end


  def test_start_input_from_last
    @player.input.stubs(:get_next).returns nil
    @player.input.stubs(:eof?).returns false

    @player.concurrency = 5
    @player.queue << "mock_request"

    thread = @player.start_input!
    assert_equal Thread, thread.class

    sleep 0.2
    assert_equal Array.new(10, "mock_request"), @player.queue

    @player.queue.slice!(8)

    sleep 0.2
    assert_equal Array.new(10, "mock_request"), @player.queue

  ensure
    thread.kill
  end


  def test_start_input_no_input
    @player.input.stubs(:eof?).returns true

    @player.concurrency = 5
    @player.queue << "mock_request"

    thread = @player.start_input!
    assert_equal Thread, thread.class

    sleep 0.2
    assert_equal ["mock_request"], @player.queue

  ensure
    thread.kill
  end


  def test_next_input
    @player.input.expects(:get_next).returns "NEXT ITEM"
    assert_equal "NEXT ITEM", @player.trigger(:input)

    @player.input.expects(:get_next).returns nil
    @player.queue.concat ["FIRST ITEM", "QUEUE REPEAT"]
    assert_equal "QUEUE REPEAT", @player.trigger(:input)

    @player.input.expects(:get_next).returns nil
    @player.queue.clear
    @player.instance_variable_set "@last_req", "LAST REQ"
    assert_equal "LAST REQ", @player.trigger(:input)

    @player.input.expects(:get_next).returns nil
    @player.queue.clear
    @player.instance_variable_set "@last_req", nil
    assert_equal Hash.new, @player.trigger(:input)
  end


  def test_process_compare_one
    mock_thread = "mock_thread"
    Thread.expects(:new).twice.yields.returns mock_thread
    mock_thread.expects(:join).twice

    resp1 = Kronk::Response.new mock_resp("200_response.json")
    resp1.parser = JSON
    resp2 = Kronk::Response.new mock_resp("200_response.txt")

    req1 = Kronk::Request.new "example.com"
    req2 = Kronk::Request.new "beta-example.com"

    Kronk::Request.expects(:new).returns req2
    Kronk::Request.expects(:new).returns req1

    req1.expects(:retrieve).returns resp1
    req2.expects(:retrieve).returns resp2

    @got_results = nil

    @player.output.expects(:result).with do |kronk, mutex|
      @got_results = true
      assert_equal @player.mutex, mutex
      assert_equal Kronk::Diff.new(resp1.stringify, resp2.stringify).formatted,
                    kronk.diff.formatted
      true
    end

    opts = {:uri_suffix => "/test", :include_headers => true}
    @player.process_one opts, :compare, "example.com", "beta-example.com"

    assert @got_results, "Expected output to get results but didn't"
  end


  def test_process_one_compare_error
    @got_results = []

    @player.output.expects(:error).times(3).with do |error, kronk, mutex|
      @got_results << error.class
      assert_equal @player.mutex, mutex
      assert_equal Kronk,         kronk.class
      true
    end

    errs = [Kronk::Exception, Kronk::Response::MissingParser, Errno::ECONNRESET]
    errs.each do |eklass|
      Kronk.any_instance.expects(:compare).
        with("example.com", "beta-example.com").
        raises eklass

      opts = {:uri_suffix => "/test", :include_headers => true}
      @player.process_one opts, :compare, "example.com", "beta-example.com"
    end

    assert_equal errs, @got_results, "Expected output to get errors but didn't"
  end


  def test_process_one_compare_error_not_caught
    Kronk.any_instance.expects(:compare).
      with("example.com", "beta-example.com").
      raises RuntimeError

    assert_raises RuntimeError do
      opts = {:uri_suffix => "/test", :include_headers => true}
      @player.process_one opts, :compare, "example.com", "beta-example.com"
    end
  end


  def test_process_one_request
    resp = Kronk::Response.new mock_resp("200_response.json")
    resp.parser = JSON

    req = Kronk::Request.new "example.com"
    req.expects(:retrieve).returns resp

    Kronk::Request.expects(:new).returns req

    @got_results = nil

    @player.output.expects(:result).with do |kronk, mutex|
      @got_results = true
      assert_equal @player.mutex, mutex
      assert_equal resp, kronk.response
      true
    end

    opts = {:uri_suffix => "/test", :include_headers => true}
    @player.process_one opts, :request, "example.com"

    assert @got_results, "Expected output to get results but didn't"
  end


  def test_process_one_request_error
    @got_results = []

    @player.output.expects(:error).times(3).with do |error, kronk, mutex|
      @got_results << error.class
      assert_equal @player.mutex, mutex
      assert_equal Kronk,         kronk.class
      true
    end

    errs = [Kronk::Exception, Kronk::Response::MissingParser, Errno::ECONNRESET]
    errs.each do |eklass|
      Kronk.any_instance.expects(:request).with("example.com").
        raises eklass

      opts = {:uri_suffix => "/test", :include_headers => true}
      @player.process_one opts, :request, "example.com"
    end

    assert_equal errs, @got_results, "Expected output to get errors but didn't"
  end


  def test_process_one_request_error_not_caught
    Kronk.any_instance.expects(:request).with("example.com").
      raises RuntimeError

    assert_raises RuntimeError do
      opts = {:uri_suffix => "/test", :include_headers => true}
      @player.process_one opts, :request, "example.com"
    end
  end


  private

  def mock_requests *setup
    resp = []
    req  = []

    opts = setup.length > 1 && Hash === setup.last ?
            setup.delete_at(-1) : Hash.new

    case setup.first
    when Hash
      hash = setup.first
      req  = hash.keys
      resp = req.map{|k| hash[k]}

    when String
      req = setup
      resp = [mock_resp("200_response.txt")] * setup.length
    end

    req.each_with_index do |r, i|
      mock_req = "mock request"
      mock_res = Kronk::Response.new resp[i]
      Kronk::Request.stubs(:new).with(req[i], opts).returns mock_req
      mock_req.stubs(:retrieve).returns mock_res
      mock_req.stubs(:uri).returns nil
    end
  end
end
