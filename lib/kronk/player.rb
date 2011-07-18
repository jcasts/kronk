class Kronk

  class Player

    # Matcher to parse request from.
    # Assigns http method to $1 and path info to $2.
    LOG_MATCHER = %r{([A-Za-z]+) (/[^\s"]+)[\s"]}

    attr_accessor :max_threads, :max_requests, :queue

    def initialize opts={}
      @max_requests = opts[:max_requests]
      @max_threads  = opts[:max_threads]
      @max_threads  = 4 if !@max_threads || @max_threads <= 0

      @queue      = []
      @threads    = []
      @io         = nil
      @io_parser  = LOG_MATCHER
      #@io_timeout = opts[:io_timeout] || 5
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
    # Returns the number of failures + errors.
    # If options are given, they are merged into every request.

    def compare uri1, uri2, opts={}
      total_time    = 0
      error_count   = 0
      failure_count = 0

      $stdout.puts "Started"

      process_queue do |kronk_opts|
        bad_count = error_count + failure_count + 1
        start     = Time.now

        status    = process_compare bad_count, uri1, uri2, kronk_opts.merge(opts)
        elapsed   = Time.now - start

        total_time    += elapsed.to_f
        error_count   += 1 if status == "E"
        failure_count += 1 if status == "F"

        $stdout << status
        $stdout.flush
      end

      $stdout.puts "\nFinished in #{total_time} seconds.\n"

      $stderr.flush

      $stdout.puts "\n#{failure_count} failures, #{error_count} errors"

      @queue.clear

      error_count + failure_count
    end


    ##
    # Start processing the queue and reading from IO if available.

    def process_queue
      count = 0

      until finished? count
        while @threads.length >= @max_threads
          sleep 0.1
        end

        try_read_from_io

        kronk_opts = @queue.shift

        @threads << Thread.new do
          yield kronk_opts
          @threads.delete Thread.current
        end

        count += 1
      end

      @threads.each{|t| t.join}
    end


    ##
    # Attempt to fill the queue by reading from the IO instance.

    def try_read_from_io
      return if !@io || @io.eof? ||
                @queue.length >= @max_threads * 2

      max_new = @max_threads * 2 - @queue.length

      max_new.times do
        break if @io.eof?
        @queue << request_from_io
      end
    end


    ##
    # Get one line from the IO instance and parse it into a kronk_opts hash.

    def request_from_io
      line = @io.gets

      if @io_parser.respond_to? :call
        @io_parser.call line

      elsif Regexp === @io_parser && line =~ @io_parser
        {:http_method => $1, :uri_suffix => $2}

      else
        {:uri_suffix => line}
      end
    end


    ##
    # Returns true if processing queue should be stopped, otherwise false.

    def finished? count
      (@max_requests && @max_requests >= count) || @queue.empty? &&
      (!@io || @io && @io.eof?)
    end


    def process_compare count, uri1, uri2, opts={}
      status = '.'

      begin
        diff = Kronk.compare uri1, uri2, opts

        if diff.count > 0
          status = 'F'
          $stderr.write failure_text(count, uri1, uri2, opts, diff)
        end

      rescue => e
        status = 'E'
        $stderr.write error_text(count, uri1, uri2, opts, e)
      end

      status
    end


    def failure_text count, uri1, uri2, opts, diff
      <<-STR
  #{count}) Failure:
Compare: #{uri1}
         #{uri2}

Options: #{opts_to_s(opts)}

Diffs: #{diff.count}
      STR
    end


    def error_text count, uri1, uri2, opts, err
      <<-STR
  #{count}) Error:
#{err.class}: #{err.message}

Compare: #{uri1}
         #{uri2}

Options: #{opts_to_s(opts)}
      STR
    end


    def opts_to_s opts
"OPTIONS PLACEHOLDER"
    end
  end
end
