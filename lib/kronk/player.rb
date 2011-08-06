class Kronk

  ##
  # The Player class is used for running multiple requests and comparisons and
  # providing useful output through Player::Output classes.
  # Kronk includes a Suite (test-like) output, a Stream (chunked) output,
  # and a Benchmark output.

  class Player

    attr_accessor :number, :concurrency, :queue, :count, :input
    attr_reader :output

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
      self.output  = opts[:output] || Suite

      @count     = nil
      @queue     = []
      @threads   = []
      @input     = InputReader.new opts[:io], opts[:parser]

      @result_mutex = Mutex.new
    end


    ##
    # The kind of output to use. Typically Player::Suite or Player::Stream.
    # Takes an output class or a string that represents a class constant.

    def output= new_output
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
    # Adds kronk request hash options to queue.
    # See Kronk#compare for supported options.

    def queue_req kronk_opts
      @queue << kronk_opts
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

    def compare uri1, uri2, opts={}
      process_queue do |kronk_opts, suite|
        return Cmd.compare(uri1, uri2, kronk_opts.merge(opts)) unless suite
        process_compare uri1, uri2, kronk_opts.merge(opts)
      end
    end


    ##
    # Process the queue to request uris.
    # If options are given, they are merged into every request.

    def request uri, opts={}
      process_queue do |kronk_opts, suite|
        return Cmd.request(uri, kronk_opts.merge(opts)) unless suite
        process_request uri, kronk_opts.merge(opts)
      end
    end


    ##
    # Start processing the queue and reading from IO if available.
    # Calls Output#start method and returns the value of Output#completed
    # once processing is finished.
    #
    # Yields queue item and if it will be the only item or part of a
    # suite, until queue and io (if available) are empty and the
    # totaly number of requests to run is met (if number is set).

    def process_queue
      # First check if we're only processing a single case.
      # If so, yield a single item and return immediately.
      @queue << next_request if @queue.empty? && (!@number || @number <= 1)
      if @queue.length == 1 && @input.eof?
        yield @queue.shift, false
        return
      end

      trap 'INT' do
        @threads.each{|t| t.kill}
        @threads.clear
        output_results
        exit 2
      end

      @output.start

      reader_thread = try_fill_queue

      @count = 0

      until finished?
        @threads.delete_if{|t| !t.alive? }
        next if @threads.length >= @concurrency || @queue.empty?

        kronk_opts = @queue.shift

        @threads << Thread.new(kronk_opts) do |thread_opts|
          yield thread_opts, true
        end

        @count += 1
      end

      @threads.each{|t| t.join}
      @threads.clear

      reader_thread.kill

      output_results
    end


    ##
    # Attempt to fill the queue by reading from the IO instance.
    # Starts a new thread and returns the thread instance.

    def try_fill_queue
      Thread.new do
        loop do
          break if !@number && @input.eof?
          next if @queue.length >= @concurrency * 2

          max_new = @concurrency * 2 - @queue.length

          max_new.times do
            req = next_request
            @queue << req if req
          end
        end
      end
    end


    ##
    # Get one line from the IO instance and parse it into a kronk_opts hash.

    def next_request
      @input.get_next || @queue.last || Hash.new
    end


    ##
    # Returns true if processing queue should be stopped, otherwise false.

    def finished?
      (@number && @count >= @number) || @queue.empty? &&
      @input.eof? && @count > 0
    end


    ##
    # Process and output the results.
    # Calls Output#completed method.

    def output_results
      @output.completed
    end


    ##
    # Run a single compare and call the Output#result or Output#error method.

    def process_compare uri1, uri2, opts={}
      kronk = Kronk.new opts
      kronk.compare uri1, uri2
      @output.result kronk, @result_mutex

    rescue Kronk::Exception, Response::MissingParser, Errno::ECONNRESET => e
      @output.error e, kronk, @result_mutex
    end


    ##
    # Run a single request and call the Output#result or Output#error method.

    def process_request uri, opts={}
      kronk = Kronk.new opts
      kronk.retrieve uri
      @output.result kronk, @result_mutex

    rescue Kronk::Exception, Response::MissingParser, Errno::ECONNRESET => e
      @output.error e, kronk, @result_mutex
    end
  end
end
