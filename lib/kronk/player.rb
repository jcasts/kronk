class Kronk

  # TODO: Loadtest mode?
  #       Add support for full HTTP Request parsing
  #       Make all parsers a class?

  class Player

    # Matcher to parse request from.
    # Assigns http method to $1 and path info to $2.
    LOG_MATCHER = %r{([A-Za-z]+) (/[^\s"]+)[\s"]*}

    attr_accessor :number, :concurrency, :queue, :count

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
      self.output  = opts[:output] || SuiteOutput

      @count     = nil
      @queue     = []
      @threads   = []
      @io        = opts[:io]
      @io_parser = opts[:parser] || LOG_MATCHER
    end


    ##
    # The kind of output to use. Typically SuiteOutput or StreamOutput.
    # Takes an output class or a string that represents a class constant.

    def output= new_output
      return @output = new_output.new if Class === new_output

      klass =
        case new_output.to_s
        when /^(Player::)?stream(Output)?$/i
          StreamOutput

        when /^(Player::)?suite(Output)?$/i
          SuiteOutput

        else
          Kronk.find_const new_output
        end

      @output = klass.new if klass
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
    # Parser can be a..
    # * Regexp: $1 used as http_method, $2 used as path_info
    # * Proc: return value should be a kronk options hash.
    #   See Kronk#compare for supported options.
    #
    # Default parser is LOG_MATCHER.

    def from_io io, parser=nil
      @io = io
      @io_parser = parser if parser
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

    def process_queue
      # First check if we're only processing a single case.
      # If so, yield a single item and return immediately.
      @queue << request_from_io if @io && !@number
      if @queue.length == 1 && (!@io || @io.eof?)
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

      reader_thread = try_read_from_io

      @count = 0

      until finished?
        while @threads.length >= @concurrency || @queue.empty?
          sleep 0.1
        end

        kronk_opts = @queue.shift

        @threads << Thread.new(kronk_opts) do |thread_opts|
          begin
            yield thread_opts, true
          ensure
            @threads.delete Thread.current
          end
        end

        @count += 1
      end

      @threads.each{|t| t.join}
      @threads.clear

      reader_thread.kill

      success = output_results
      exit 1 unless success
    end


    ##
    # Attempt to fill the queue by reading from the IO instance.
    # Starts a new thread and returns the thread instance.

    def try_read_from_io
      Thread.new do
        loop do
          break if !@io || @io.eof?
          next  if @queue.length >= @concurrency * 2

          max_new = @concurrency * 2 - @queue.length

          max_new.times do
            req = request_from_io
            @queue << req if req

            if @io.eof?
              missing_num = @number.to_i - (@count + @queue.length)
              @queue.concat Array.new(missing_num, req) if missing_num > 0
              break
            end
          end
        end
      end
    end


    ##
    # Get one line from the IO instance and parse it into a kronk_opts hash.

    def request_from_io
      line = @io.gets.strip

      if @io_parser.respond_to? :call
        @io_parser.call line

      elsif Regexp === @io_parser && line =~ @io_parser
        {:http_method => $1, :uri_suffix => $2}

      elsif line && !line.empty?
        {:uri_suffix => line}
      end
    end


    ##
    # Returns true if processing queue should be stopped, otherwise false.

    def finished?
      (@number && @count >= @number) || @queue.empty? &&
      (!@io || @io && @io.eof?) && @count > 0
    end


    ##
    # Process and output the results.

    def output_results
      @output.completed
    end


    ##
    # Run a single compare and return a result array.

    def process_compare uri1, uri2, opts={}
      kronk = Kronk.new opts
      kronk.compare uri1, uri2
      @output.result kronk

    rescue Kronk::Exception, Response::MissingParser, Errno::ECONNRESET => e
      @output.error e, kronk
    end


    ##
    # Run a single request and return a result array.

    def process_request uri, opts={}
      kronk = Kronk.new opts
      kronk.retrieve uri
      @output.result kronk

    rescue Kronk::Exception, Response::MissingParser, Errno::ECONNRESET => e
      @output.error e, kronk
    end
  end
end
