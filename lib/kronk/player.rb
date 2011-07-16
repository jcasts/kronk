class Kronk

  class Player

    # Matcher to parse request from.
    # Assigns http method to $1 and path info to $2.
    LOG_MATCHER = %r{([A-Za-z]+) (/[^\s"]+)[\s"]}

    attr_accessor :max_threads, :max_requests, :queue

    def initialize opts={}
      @max_requests = opts[:max_requests]
      @max_threads  = opts[:max_threads]
      @max_threads  = 10 if !@max_threads || @max_threads <= 0

      @queue   = []
      @threads = []
    end


    ##
    # Adds kronk request options to queue.

    def queue_req kronk_opts
      @queue << kronk_opts
    end


    ##
    # Adds an IO instance to the queue.

    def queue_io io, matcher=nil
      matcher ||= LOG_MATCHER
      @queue << [io, matcher]
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

      threaded_each @queue do |kronk_opts|
        bad_count = error_count + failure_count + 1
        start     = Time.now

        status    = process_request uri1, uri2, kronk_opts.merge(opts)
        elapsed   = Time.now - start_time

        total_time    += elapsed.to_f
        error_count   += 1 if status == "E"
        failure_count += 1 if status == "F"
      end

      $stdout.puts "\nFinished in #{total_time} seconds.\n"

      $stderr.flush

      $stdout.puts "\n#{failure_count} failures, #{error_count}, errors"

      @queue.clear

      error_count + failure_count
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


    def process_compare count, uri1, uri2, opts={}
      status = '.'

      begin
        diff = Kronk.compare uri1, uri2, opts

        if diff.count > 0
          status = 'F'
          $stderr << failure_text(count, uri1, uri2, opts, diff)
        end

      rescue => e
        status = 'E'
        $stderr << error_text(count, e)
      end

      $stdout << status
      $stdout.flush
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


    def error_text count, err
      <<-STR
  #{count}) Error:
#{err.class}: #{err.message}
      STR
    end


    def opts_to_s opts
"OPTIONS PLACEHOLDER"
    end
  end
end
