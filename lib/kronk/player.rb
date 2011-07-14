class Kronk

  class Player

    # Matcher to parse request from.
    # Assigns http method to $1 and path info to $2.
    LOG_MATCHER = %r{([A-Za-z]+) (/[^\s"]+)[\s"]}

    attr_accessor :max_threads, :queue, :results

    def initialize opts={}
      @stderr      = opts[:errout] || $stderr
      @stdout      = opts[:stdout] || $stdout

      @max_threads = opts[:max_threads]
      @max_threads = 10 if !@max_threads || @max_threads <= 0

      @queue       = []
      @threads     = []
    end


    ##
    # Adds kronk request options to queue.

    def queue_req kronk_opts
      @queue << kronk_opts.dup
    end


    ##
    # Adds an IO instance to the queue.

    def queue_io io, opts={}
      matcher = opts.delete(:matcher) || LOG_MATCHER
      @queue << [io, matcher]
    end


    ##
    # Process the comparison queue.
    # Returns true if no diffs were found (success), otherwise false.

    def run uri1, uri2
      start_time = Time.now

      error_count   = 0
      failure_count = 0

      threaded_each @queue do |args|
        status = process_request uri1, uri2, args

        error_count   += 1 if status == "E"
        failure_count += 1 if status == "F"
      end

      time = Time.now - start_time
      @stdout.puts "\nFinished in #{time.to_f} seconds.\n"

      @stderr.flush

      @stdout.puts "\n#{failure_count} failures, #{error_count}, errors"

      return success?
    end


    ##
    # Run anything from the thread pool.

    def threaded_each arr
      arr.each do |item|
        while @threads.length >= @max_threads
          sleep 0.2
        end

        @threads << Thread.new do
          yield item
          @threads.delete Thread.current
        end
      end

      @threads.each{|t| t.join}
    end


    def process_compare uri1, uri2, opts={}
      status = '.'

      begin
        diff = Kronk.compare uri1, uri2, opts
        # OR k = Kronk.request uri, opts

        if diff.count > 0
          status = 'F'
          @stderr << failure_text(uri1, uri2, opts, diff)
        end

      rescue => e
        status = 'E'
        @stderr << error_text(e)
      end

      @stdout << status
      @stdout.flush
      status
    end


    def failure_text uri1, uri2, opts, diff
    end


    def error_text err
    end
  end
end
