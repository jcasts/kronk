require 'test/test_helper'

class TestPlayer < Test::Unit::TestCase

  class MockPipe < StringIO; end

  class MockPlayer < Kronk::Player
    attr_accessor :result_calls

    def start
      @result_calls = 0
    end

    def result kronk
      @mutex.synchronize do
        @result_calls += 1
      end
    end

    def interrupt
      raise "Interrupted"
    end
  end

  class MockParser
    def self.parse str
      str
    end
  end


  def setup
    @io        = MockPipe.new
    @parser    = MockParser
    @player    = MockPlayer.new :io     => @io,
                                :parser => @parser

    @player.on(:result){|(kronk, err)| @player.trigger_result(kronk, err) }
  end


  def test_init_defaults
    player = Kronk::Player.new_type 'suite'
    assert_equal Kronk::Player::Suite,       player.class
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
    player = Kronk::Player.new_type :stream,
                                    :number      => 1000,
                                    :concurrency => 10

    assert_equal Kronk::Player::Stream,        player.class
    assert_equal Kronk::Player::RequestParser, player.input.parser
    assert_equal 10,                           player.concurrency
    assert_equal 1000,                         player.number
  end


  def test_new_type
    @player = Kronk::Player.new_type :benchmark
    assert_equal Kronk::Player::Benchmark, @player.class

    @player = Kronk::Player.new_type :stream
    assert_equal Kronk::Player::Stream, @player.class

    @player = Kronk::Player.new_type :suite
    assert_equal Kronk::Player::Suite, @player.class

    assert_raises NameError do
      @player = Kronk::Player.new_type :foo
    end
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


  def test_compare
    @player.input.parser = Kronk::Player::RequestParser
    @player.input.io << "/req3\n/req4\n/req5\n"
    @player.input.io.rewind
    @player.input.io.close_write

    @player.queue.concat [{:path => "/req1"}, {:path => "/req2"}]

    part1 = (1..2).map{|n| "/req#{n}"}
    part2 = (3..5).map{|n| "/req#{n}"}

    part1.each do |path|
      mock_requests "example.com", "beta-example.com",
        :path  => path,
        :query => "foo=bar"
    end

    part2.each do |path|
      mock_requests "example.com", "beta-example.com",
        :path  => path,
        :query => "foo=bar"
    end

    @player.compare "example.com", "beta-example.com", :query => "foo=bar"

    assert_equal 5, @player.result_calls
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
    @player.instance_eval "undef interrupt"

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


  def test_concurrently
    requests = (1..20).map{|n| "request #{n}"}
    @player.queue.concat requests.dup
    @player.input.io.close

    start     = Time.now
    processed = []

    @player.concurrently 10 do |req|
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


  def test_concurrently_from_io
    @player.input.parser.stubs(:start_new?).returns true
    @player.input.parser.stubs(:start_new?).with("").returns false

    processed  = []
    start_time = 0
    time_spent = 0

    requests = (1..20).map{|n| "request #{n}\n"}
    @player.from_io StringIO.new(requests.join)

    start_time = Time.now
    @player.concurrently 10 do |req|
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


  def test_start_input_from_input
    @player.input.stubs(:get_next).returns "mock_request"

    @player.number = 30

    thread = @player.start_input! 10
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

    @player.queue << "mock_request"

    thread = @player.start_input! 10
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


  def test_run
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

    @player.expects(:result).with do |kronk|
      @got_results = true
      assert_equal Kronk::Diff.new(resp1.stringify, resp2.stringify).formatted,
                    kronk.diff.formatted
      true
    end

    opts = {:uri_suffix => "/test", :include_headers => true}
    @player.number = 1
    @player.concurrency = 1
    @player.queue << opts

    @player.run do |kronk|
      kronk.compare "example.com", "beta-example.com"
    end

    assert @got_results, "Expected player to get results but didn't"
  end


  def test_run_error
    @got_results = []
    @player.number = 1
    @player.concurrency = 1

    @player.expects(:error).times(3).with do |error, kronk|
      @got_results << error.class
      assert_equal Kronk, kronk.class
      true
    end

    errs = [Kronk::Error, Kronk::Response::MissingParser, Errno::ECONNRESET]
    errs.each do |eklass|
      Kronk.any_instance.expects(:compare).
        with("example.com", "beta-example.com").
        raises eklass

      opts = {:uri_suffix => "/test", :include_headers => true}

      @player.run opts do |kronk|
        kronk.compare "example.com", "beta-example.com"
      end
    end

    assert_equal errs, @got_results, "Expected player to get errors but didn't"
  end


  def test_run_error_not_caught
    @player.number = 1
    @player.concurrency = 1

    Kronk.any_instance.expects(:compare).
      with("example.com", "beta-example.com").
      raises ArgumentError

    assert_raises ArgumentError do
      opts = {:uri_suffix => "/test", :include_headers => true}

      @player.run opts do |kronk|
        kronk.compare "example.com", "beta-example.com"
      end
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
      mock_res = Kronk::Response.new resp[i]
      mock_req = stub("mock_req", :retrieve => mock_res,
                        :uri => URI.parse("http://host.com"))

      Kronk::Request.stubs(:new).with(req[i], opts).returns mock_req
    end
  end
end
