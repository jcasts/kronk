class Kronk

  ##
  # The Player class is used for running multiple requests and comparisons and
  # providing useful output through Player::Output classes.
  # Kronk includes a Suite (test-like) output, a Stream (chunked) output,
  # and a Benchmark output.

  class Player

    attr_accessor :number, :concurrency, :queue, :count, :input
    attr_reader :output, :mutex, :threads

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

      @count     = 0
      @queue     = []
      @threads   = []
      @input     = InputReader.new opts[:io], opts[:parser]

      @mutex = Mutex.new
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
      return Cmd.compare uri1, uri2, @queue.shift.merge(opts) if single_request?

      process_queue do |kronk_opts, suite|
        return Cmd.compare(uri1, uri2, kronk_opts.merge(opts)) unless suite
        process_compare uri1, uri2, kronk_opts.merge(opts)
      end
    end


    ##
    # Process the queue to request uris.
    # If options are given, they are merged into every request.

    def request uri, opts={}
      return Cmd.request(uri, @queue.shift.merge(opts)) if single_request?

      process_queue do |kronk_opts|
        process_request uri, kronk_opts.merge(opts)
      end
    end


    ##
    # Check if we're only processing a single case.
    # If so, yield a single item and return immediately.
    def single_request?
      @queue << next_request if @queue.empty? && (!@number || @number <= 1)
      @queue.length == 1 && @input.eof?
    end


    ##
    # Start processing the queue and reading from IO if available.
    # Calls Output#start method and returns the value of Output#completed
    # once processing is finished.
    #
    # Yields queue item until queue and io (if available) are empty and the
    # totaly number of requests to run is met (if number is set).

    def process_queue
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
          yield thread_opts
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
          next  if @queue.length >= @concurrency * 2

          max_new = @concurrency * 2 - @queue.length

          max_new.times do
            @queue << next_request
          end
        end
      end
    end


    ##
    # Gets the next request to perform and always returns a Hash.
    # Tries from input first, then from the last item in the queue.
    # If both fail, returns an empty Hash.

    def next_request
      @last_req = @input.get_next || @queue.last || @last_req || Hash.new
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
      @output.result kronk, @mutex

    rescue Kronk::Exception, Response::MissingParser, Errno::ECONNRESET => e
      @output.error e, kronk, @mutex
    end


    ##
    # Run a single request and call the Output#result or Output#error method.

    def process_request uri, opts={}
      kronk = Kronk.new opts
      kronk.retrieve uri
      @output.result kronk, @mutex

    rescue Kronk::Exception, Response::MissingParser, Errno::ECONNRESET => e
      @output.error e, kronk, @mutex
    end
  end
end
