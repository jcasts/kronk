class Kronk

  # TODO: Add support for full HTTP Request parsing
  #       Only use Player when stream has more than 1 request

  class Player

    # Matcher to parse request from.
    # Assigns http method to $1 and path info to $2.
    LOG_MATCHER = %r{([A-Za-z]+) (/[^\s"]+)[\s"]*}

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

      @results = []
      @last    = nil

      @player_start_time = nil
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
      @results.clear

      $stdout.puts "Started"

      trap 'INT' do
        @threads.each{|t| t.kill}
        @threads.clear
        output_results
        exit 2
      end

      process_queue do |kronk_opts|
        result = process_compare uri1, uri2, kronk_opts.merge(opts)

        @results << result
        $stdout  << result[0]
        $stdout.flush
      end

      success = output_results
      exit 1 unless success
    end


    ##
    # Process the queue to request uris.
    # If options are given, they are merged into every request.

    def request uri, opts={}
      @results.clear

      $stdout.puts "Started"

      trap 'INT' do
        @threads.each{|t| t.kill}
        @threads.clear
        output_results
        exit 2
      end

      process_queue do |kronk_opts|
        result = process_request uri, kronk_opts.merge(opts)

        @results << result
        $stdout  << result[0]
        $stdout.flush
      end

      success = output_results
      exit 1 unless success
    end


    ##
    # Start processing the queue and reading from IO if available.

    def process_queue
      @player_start_time = Time.now

      reader_thread = try_read_from_io

      count = 0

      until finished? count
        while @threads.length >= @max_threads || @queue.empty?
          sleep 0.1
        end

        kronk_opts = @queue.shift
        next unless kronk_opts

        @threads << Thread.new(kronk_opts) do |thread_opts|
          yield thread_opts
          @threads.delete Thread.current
        end

        count += 1
      end

      @threads.each{|t| t.join}
      @threads.clear

      reader_thread.kill
    end


    ##
    # Attempt to fill the queue by reading from the IO instance.
    # Starts a new thread and returns the thread instance.

    def try_read_from_io
      Thread.new do
        loop do
          break if !@io || @io.eof?
          next  if @queue.length >= @max_threads * 2

          max_new = @max_threads * 2 - @queue.length

          max_new.times do
            break if @io.eof?
            req = request_from_io
            @queue << req if req
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

    def finished? count
      (@max_requests && @max_requests >= count) || @queue.empty? &&
      (!@io || @io && @io.eof?) && count > 0
    end


    ##
    # Process and output the results.

    def output_results
      if @results.length == 1 && @results[0][0] != "E"
        puts "\n"
        Cmd.render @last
      end

      player_time   = (Time.now - @player_start_time).to_f
      total_time    = 0
      bad_count     = 0
      failure_count = 0
      error_count   = 0
      err_buffer    = ""

      @results.each do |(status, time, text)|
        total_time += time.to_f

        case status
        when "F"
          bad_count     += 1
          failure_count += 1
          err_buffer << "  #{bad_count}) Failure:\n#{text}"

        when "E"
          bad_count   += 1
          error_count += 1
          err_buffer << "  #{bad_count}) Error:\n#{text}"
        end
      end

      avg_time = total_time / @results.length

      $stdout.puts "\nFinished in #{player_time} seconds.\n\n"
      $stderr.puts err_buffer
      $stdout.puts "#{@results.length} cases, " +
                   "#{failure_count} failures, #{error_count} errors"

      $stdout.puts "Avg Time: #{avg_time}"
      $stdout.puts "Avg QPS: #{@results.length / player_time}"

      return bad_count == 0
    end


    ##
    # Run a single compare and return a result array.

    def process_compare uri1, uri2, opts={}
      status = '.'

      begin
        kronk   = Kronk.new opts
        diff    = kronk.compare uri1, uri2
        elapsed =
          (kronk.responses[0].time.to_f + kronk.responses[0].time.to_f) / 2

        @last  = kronk

        if diff.count > 0
          status = 'F'
          return [status, elapsed, diff_text(kronk)]
        end

        return [status, elapsed]

      rescue => e
        status  = 'E'
        return [status, 0, error_text(kronk, e)]
      end
    end


    ##
    # Run a single request and return a result array.

    def process_request uri, opts={}
      status = '.'

      begin
        kronk   = Kronk.new opts
        resp    = kronk.retrieve uri
        elapsed = resp.time.to_f

        @last = kronk

        unless resp.code =~ /^2\d\d$/
          status = 'F'
          return [status, elapsed, status_text(kronk)]
        end

        return [status, elapsed]

      rescue => e
        status  = 'E'
        return [status, 0, error_text(kronk, e)]
      end
    end


    private

    def status_text kronk
      <<-STR
  Request: #{kronk.response.code} - #{kronk.response.uri}
  Options: #{kronk.options.inspect}

      STR
    end


    def diff_text kronk
      <<-STR
  Request: #{kronk.responses[0].code} - #{kronk.responses[0].uri}
           #{kronk.responses[1].code} - #{kronk.responses[1].uri}
  Options: #{kronk.options.inspect}
  Diffs: #{kronk.diff.count}

      STR
    end


    def error_text kronk, err
      <<-STR
#{err.class}: #{err.message}
  Options: #{kronk.options.inspect}

      STR
    end
  end
end
