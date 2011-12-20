class Kronk

  ##
  # The Player class is used for running multiple requests and comparisons and
  # providing useful output through Player::Output classes.
  # Kronk includes a Suite (test-like) output, a Stream (chunked) output,
  # and a Benchmark output.

  class Player < QueueRunner

    attr_accessor :input, :output, :qps, :concurrency, :mutex

    ##
    # Create a new Player for batch diff or response validation.
    # Supported options are:
    # :io:: IO - The IO instance to read from
    # :output:: Class - The output class to use (see Player::Output)
    # :parser:: Class - The IO parser to use.
    # :concurrency:: Fixnum - Maximum number of concurrent items to process
    # :qps::  Fixnum - Number of queries to process per second

    def initialize opts={}
      super

      @concurrency = opts[:concurrency]
      @concurrency = 1 if !@concurrency || @concurrency <= 0
      @qps         = opts[:qps]

      self.output_from opts[:output] || Suite

      @input      = InputReader.new opts[:io], opts[:parser]
      @use_output = true
      @last_req   = nil
      @mutex      = Mutex.new

      @on_input   = Proc.new do
        stop_input! if !@number && @input.eof?
        @last_req = @input.get_next || @queue.last || @last_req || {}
      end

      @on_result  = Proc.new do |kronk, err, mutex|
        err ? @output.error(err, kronk, mutex) :
              @output.result(kronk, mutex)
      end

      on(:input, &@on_input)
      on(:interrupt){
        @output.completed if @use_output
        exit 2
      }
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

      on(:result){|(kronk, err)| trigger_result(kronk, err, &block) }

      run opts do |kronk|
        kronk.compare uri1, uri2
      end
    end


    ##
    # Process the queue to request uris.
    # If options are given, they are merged into every request.

    def request uri, opts={}, &block
      return Cmd.request uri, @queue.shift.merge(opts) if single_request?

      on(:result){|(kronk, err)| trigger_result(kronk, err, &block) }

      run opts do |kronk|
        kronk.request uri
      end
    end


    ##
    # Similar to QueueRunner#run but yields a Kronk instance.

    def run opts={}
      if @qps
        method = :periodically
        arg    = 1.0 / @qps.to_f
      else
        method = :concurrently
        arg    = @concurrency
      end

      send method, arg do |kronk_opts|
        err = nil
        kronk = Kronk.new kronk_opts.merge(opts)

        begin
          yield kronk
        rescue *Kronk::Cmd::RESCUABLE => e
          err = e
        end

        [kronk, err]
      end
    end


    ##
    # Trigger a single kronk result callback.

    def trigger_result kronk, err, &block
      block ||= @on_result

      if block.arity > 2 || block.arity < 0
        block.call kronk, err, @mutex
      else
        @mutex.synchronize do
          block.call kronk, err
        end
      end
    end


    ##
    # Check if we're only processing a single case.
    # If so, yield a single item and return immediately.

    def single_request?
      @queue << trigger(:input) if @queue.empty? && (!@number || @number <= 1)
      @queue.length == 1 && @triggers[:input] == @on_input && @input.eof?
    end


    private :on
  end
end
