class Kronk

  ##
  # The Player class is used for running multiple requests and comparisons and
  # providing useful output through Player::Output classes.
  # Kronk includes a Suite (test-like) output, a Stream (chunked) output,
  # and a Benchmark output.

  class Player

    attr_accessor :number, :concurrency, :queue, :count, :input, :input_proc,
                  :output, :mutex, :threads, :reader_thread

    ##
    # Create a new Player for batch diff or response validation.
    # Supported options are:
    # :concurrency:: Fixnum - The maximum number of concurrent requests to make
    # :number:: Fixnum - The number of requests to make
    # :io:: IO - The IO instance to read from
    # :output:: Class - The output class to use (see Player::Output)
    # :parser:: Class - The IO parser to use.

    def initialize opts={}
      @number      = opts[:number]
      @concurrency = opts[:concurrency]
      @concurrency = 1 if !@concurrency || @concurrency <= 0
      self.output_from opts[:output] || Suite

      @count      = 0
      @queue      = []
      @threads    = []
      @input      = InputReader.new opts[:io], opts[:parser]

      @reader_thread = nil

      @input_proc = nil
      @last_req   = nil

      @mutex = Mutex.new
    end


    ##
    # The kind of output to use. Typically Player::Suite or Player::Stream.
    # Takes an output class or a string that represents a class constant.

    def output_from new_output
      return @output = new_output.new(self) if Class === new_output

      klass =
        case new_output.to_s
        when /^(Player::)?benchmark$/i then Benchmark
        when /^(Player::)?stream$/i    then Stream
        when /^(Player::)?suite$/i     then Suite
        else
          Kronk.find_const new_output
        end

      @output = klass.new self if klass
    end


    ##
    # Populate the queue by reading from the given IO instance and
    # parsing it into kronk options.
    #
    # Default parser is RequestParser. See InputReader for parser requirements.

    def from_io io, parser=nil
      @input.io     = io
      @input.parser = parser if parser
      @input
    end


    ##
    # Process the queue to compare two uris.
    # If options are given, they are merged into every request.

    def compare uri1, uri2, opts={}, &block
      return Cmd.compare uri1, uri2, @queue.shift.merge(opts) if single_request?

      run !block_given? do |kronk_opts, mutex|
        process_one :compare, [uri1, uri2], kronk_opts.merge(opts), &block
      end
    end


    ##
    # Process the queue to request uris.
    # If options are given, they are merged into every request.

    def request uri, opts={}, &block
      return Cmd.request(uri, @queue.shift.merge(opts)) if single_request?

      run !block_given? do |kronk_opts, mutex|
        process_one :request, uri, kronk_opts.merge(opts), &block
      end
    end


    ##
    # Runs the queue and reads from input until it's exhausted or
    # @number is reached. Yields a queue item and a mutex when to passed
    # block:
    #
    #   player = Player.new :concurrency => 10
    #   player.queue.concat %w{item1 item2 item3}
    #
    #   player.run do |q_item, mutex|
    #     # This block is run in its own thread.
    #     mutex.synchronize{ do_something_with q_item }
    #   end

    def run use_output=false
      uris = Array(uris)[0,2]

      trap 'INT' do
        kill
        @output.completed if use_output
        exit 2
      end

      @output.start if use_output

      process_queue do |queue_item|
        yield queue_item, @mutex if block_given?
      end

      @output.completed if use_output
    end


    ##
    # Immediately end all player processing and threads.

    def kill
      stop_input!
      @threads.each{|t| t.kill}
      @threads.clear
    end


    ##
    # Check if we're only processing a single case.
    # If so, yield a single item and return immediately.

    def single_request?
      @queue << next_request if @queue.empty? && (!@number || @number <= 1)
      @queue.length == 1 && !@input_proc && @input.eof?
    end


    ##
    # Start processing the queue and reading from IO if available.
    # Calls Output#start method and returns the value of Output#completed
    # once processing is finished.
    #
    # Yields queue item until queue and io (if available) are empty and the
    # totaly number of requests to run is met (if number is set).

    def process_queue
      start_input!
      @count = 0

      until finished?
        @threads.delete_if{|t| !t.alive? }
        next if @threads.length >= @concurrency || @queue.empty?

        @threads << Thread.new(@queue.shift) do |kronk_opts|
          yield kronk_opts if block_given?
        end

        @count += 1
      end

      @threads.each{|t| t.join}
      @threads.clear

      stop_input!
    end


    ##
    # Attempt to fill the queue by reading from the IO instance.
    # Starts a new thread and returns the thread instance.

    def start_input!
      @reader_thread = Thread.new do
        begin
          loop do
            break if !@number && !@input_proc && @input.eof?
            next  if @queue.length >= @concurrency * 2

            max_new = @concurrency * 2 - @queue.length

            max_new.times do
              @queue << next_request
              break if !@number && !@input_proc && @input.eof?
            end
          end

        rescue => e
          Thread.main.raise e
        end
      end
    end


    ##
    # Gets the next request to perform and always returns a Hash.
    # Tries from input first, then from the last item in the queue.
    # If both fail, returns an empty Hash.

    def next_request
      new_req = @input_proc ? @input_proc.call : @input.get_next

      # Green-Thread scheduling is weird if previous line called Thread.kill.
      Thread.pass if RUBY_VERSION[0,3] == "1.8"

      @last_req = new_req || @queue.last || @last_req || Hash.new
    end


    ##
    # Assigns an input block to read from instead of @input. The return value
    # of the block is appended to the queue.

    def on_input &block
      @input_proc = block
    end


    ##
    # Permanently stop input reading by killing the reader thread for a given
    # Player#run or Player#process_queue session.

    def stop_input!
      @reader_thread && @reader_thread.kill
    end


    ##
    # Returns true if processing queue should be stopped, otherwise false.

    def finished?
      return true if @number && @count >= @number

      @queue.empty? && @count > 0 &&
        (!@reader_thread || !@reader_thread.alive?)
    end


    ##
    # Run a single compare or request and call the Output#result or
    # Output#error method.

    def process_one type, uris, opts={}, &block
      error = nil
      uris  = Array(uris)[0,2]
      kronk = Kronk.new opts

      begin
        kronk.send(type, *uris)
      rescue Kronk::Exception, Response::MissingParser, Errno::ECONNRESET => e
        error = e
      end

      if block_given?
        @mutex.synchronize do
          yield kronk, error
        end
      else
        error ? @output.error(error, kronk, @mutex) :
                @output.result(kronk, @mutex)
      end
    end
  end
end
