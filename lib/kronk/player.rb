class Kronk

  ##
  # The Player class is used for running multiple requests and comparisons and
  # providing useful output through Player::Output classes.
  # Kronk includes a Suite (test-like) output, a Stream (chunked) output,
  # and a Benchmark output.

  class Player < Kronk::QueueRunner

    attr_accessor :input, :output

    ##
    # Create a new Player for batch diff or response validation.
    # Supported options are:
    # :io:: IO - The IO instance to read from
    # :output:: Class - The output class to use (see Player::Output)
    # :parser:: Class - The IO parser to use.

    def initialize opts={}
      super
      self.output_from opts[:output] || Suite

      @input      = InputReader.new opts[:io], opts[:parser]
      @use_output = true
      @last_req   = nil
      @on_input   = proc do
        stop_input! if !@number && @input.eof?
        @last_req = @input.get_next || @queue.last || @last_req || {}
      end

      on(:input, &@on_input)
      on(:interrupt){ exit 2 }
      on(:start){ @output.start if @use_output }
      on(:complete){ @output.completed if @use_output }
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
    # Process the queue to compare two uris.
    # If options are given, they are merged into every request.

    def compare uri1, uri2, opts={}, &block
      return Cmd.compare uri1, uri2, @queue.shift.merge(opts) if single_request?

      using_output !block_given? do
        run do |kronk_opts, mutex|
          process_one :compare, [uri1, uri2], kronk_opts.merge(opts), &block
        end
      end
    end


    ##
    # Process the queue to request uris.
    # If options are given, they are merged into every request.

    def request uri, opts={}, &block
      return Cmd.request(uri, @queue.shift.merge(opts)) if single_request?

      using_output !block_given? do
        run do |kronk_opts, mutex|
          process_one :request, uri, kronk_opts.merge(opts), &block
        end
      end
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


    ##
    # Check if we're only processing a single case.
    # If so, yield a single item and return immediately.

    def single_request?
      @queue << trigger(:input) if @queue.empty? && (!@number || @number <= 1)
      @queue.length == 1 && @triggers[:input] == @on_input && @input.eof?
    end


    ##
    # Enable or disable output and run the block. Restores the previous
    # value of @use_output after the block is run. Returns the value of
    # the given block.

    def using_output state
      old_value, @use_output = @use_output, state
      out_value = yield
      @use_output = old_value
      out_value
    end
  end
end
