class Kronk

  ##
  # The Player class is used for running multiple requests and comparisons and
  # providing useful output through Player::Output classes.
  # Kronk includes a Suite (test-like) output, a Stream (chunked) output,
  # and a Benchmark output.

  class Player < Kronk::QueueRunner

    RESCUABLE = [Kronk::Exception, Errno::ECONNRESET, URI::InvalidURIError]

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

      method = self.class.async ? :process_one_async : :process_one

      run do |kronk_opts, mutex|
        send method, kronk_opts.merge(opts), 'compare', uri1, uri2, &block
      end
    end


    ##
    # Process the queue to request uris.
    # If options are given, they are merged into every request.

    def request uri, opts={}, &block
      return Cmd.request uri, @queue.shift.merge(opts) if single_request?

      method = self.class.async ? :process_one_async : :process_one

      run do |kronk_opts, mutex|
        send method, kronk_opts.merge(opts), 'request', uri, &block
      end
    end


    ##
    # Run a single compare or request and call the Output#result or
    # Output#error method.
    #
    # If given a block, will yield the Kronk instance and error. If
    # a third argument is given, mutex will also be passed and the
    # block won't be called from a mutex lock.
    #
    # Returns the result of the block or of the called Output method.

    def process_one opts={}, *args, &block
      err   = nil
      kronk = Kronk.new opts

      begin
        kronk.send(*args)
      rescue *RESCUABLE => e
        err = e
      end

      trigger_result kronk, err, &block
    end


    ##
    # Run a single compare or request and call the Output#result or
    # Output#error method using EventMachine.
    #
    # If given a block, will yield the Kronk instance and error. If
    # a third argument is given, mutex will also be passed and the
    # block won't be called from a mutex lock.
    #
    # Returns either a EM::MultiRequest or an EM::Connection handler.

    def process_one_async opts={}, *args, &block
      kronk = Kronk.new opts

      handler = Proc.new do |resp, err|
        raise err if err && !RESCUABLE.find{|eclass| eclass === err}
        trigger_result kronk, err, &block
      end

      method = args.shift.to_s + '_async'
      kronk.send(method, *args, &handler)
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
    # Check if w6ce5e2ce're only processing a single case.
    # If so, yield a single item and return immediately.

    def single_request?
      @queue << trigger(:input) if @queue.empty? && (!@number || @number <= 1)
      @queue.length == 1 && @triggers[:input] == @on_input && @input.eof?
    end
  end
end

Kronk::Player.async = true
puts "async: #{Kronk::Player.async}"
