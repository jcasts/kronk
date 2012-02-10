class Kronk

  ##
  # The Player class is used for running multiple requests and comparisons and
  # providing useful output through inherited Player classes.
  # Kronk includes a Suite (test-like), a Stream (chunked),
  # and a Benchmark output.

  class Player < QueueRunner

    ##
    # Instantiate a new type of player, typically :suite, :stream, or
    # :benchmark.

    def self.new_type type, opts={}
      klass =
        case type.to_s
        when /^(Player::)?benchmark$/i then Benchmark
        when /^(Player::)?stream$/i    then Stream
        when /^(Player::)?suite$/i     then Suite
        when /^(Player::)?tsv$/i       then TSV
        else
          Kronk.find_const type.to_s
        end

      klass.new opts
    end



    attr_accessor :input, :qps, :concurrency, :mutex

    ##
    # Create a new Player for batch diff or response validation.
    # Supported options are:
    # :io:: IO - The IO instance to read from
    # :parser:: Class - The IO parser to use.
    # :concurrency:: Fixnum - Maximum number of concurrent items to process
    # :qps::  Fixnum - Number of queries to process per second

    def initialize opts={}
      super

      @concurrency = opts[:concurrency]
      @concurrency = 1 if !@concurrency || @concurrency <= 0
      @qps         = opts[:qps]

      @input      = InputReader.new opts[:io], opts[:parser]
      @last_req   = nil
      @mutex      = Mutex.new

      @on_input   = Proc.new do
        stop_input! if !@number && @input.eof?
        @last_req = @input.get_next || @queue.last || @last_req || {}
      end

      on(:input, &@on_input)
      on(:interrupt){
        interrupt and return if respond_to?(:interrupt)
        complete if respond_to?(:complete)
        exit 2
      }
      on(:start){
        start if respond_to?(:start)
      }
      on(:complete){
        complete if respond_to?(:complete)
      }
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
      on(:result){|(kronk, err)| trigger_result(kronk, err, &block) }

      run opts do |kronk|
        kronk.compare uri1, uri2
      end
    end


    ##
    # Process the queue to request uris.
    # If options are given, they are merged into every request.

    def request uri, opts={}, &block
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
        args   = [(1.0 / @qps.to_f), @concurrency]
      else
        method = :concurrently
        args   = [@concurrency]
      end

      send(method, *args) do |kronk_opts|
        err = nil
        kronk = Kronk.new kronk_opts.merge(opts)

        begin
          yield kronk
        rescue *RESCUABLE => e
          err = e
        end

        [kronk, err]
      end
    end


    ##
    # Trigger a single kronk result callback.

    def trigger_result kronk, err, &block
      if block_given?
        if block.arity > 2 || block.arity < 0
          block.call kronk, err, @mutex
        else
          @mutex.synchronize do
            block.call kronk, err
          end
        end

      elsif err && respond_to?(:error)
        error err, kronk

      elsif respond_to?(:result)
        result kronk
      end
    end
  end
end
