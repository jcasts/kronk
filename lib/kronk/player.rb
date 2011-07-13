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

      @silent      = opts[:silent]

      @queue       = []
      @failures    = []
      @errors      = []
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
      @failures.clear
      @errors.clear

      @queue.each_with_index do |args, i|

        if Array === args && IO === args[0]
        end

        threaded do
          process_request uri1, uri2, args.merge(:result_index => i)
          threads.delete Thread.current
        end
      end

      @threads.each{|t| t.join}

      print_report unless @silent

      return @failures.length == 0 && @errors.length == 0
    end


    ##
    # Run anything from the thread pool.

    def threaded &block
      while @threads.length >= @max_threads
        sleep 0.2
      end

      @threads << Thread.new do
        block.call
        @threads.delete Thread.current
      end
    end


    def process_compare uri1, uri2, opts
      index = opts.delete(:result_index)

      # TODO: implement
      k = Kronk.compare uri1, uri2, opts
      # OR k = Kronk.request uri, opts

      if k.diff?
        @stdout << "F" unless @silent
        index ? @failures[index] = k : @failures << k

      else
        @stdout << "." unless @silent
      end

      @stdout.flush unless @silent
    end
  end
end
