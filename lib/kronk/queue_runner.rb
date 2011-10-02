class Kronk

  class QueueRunner

    def self.async= value
      @async = !!value
    end


    def self.async
      !!@async
    end


    attr_accessor :number, :concurrency, :queue, :count,
                  :mutex, :threads, :reader_thread

    ##
    # Create a new QueueRunner for batch multi-threaded processing.
    # Supported options are:
    # :concurrency:: Fixnum - Maximum number of concurrent items to process
    # :number:: Fixnum - Total number of items to process

    def initialize opts={}
      @number      = opts[:number]
      @concurrency = opts[:concurrency]
      @concurrency = 1 if !@concurrency || @concurrency <= 0

      @count   = 0
      @queue   = []
      @threads = []

      @reader_thread = nil

      @triggers = {}

      @mutex = Mutex.new
    end


    ##
    # Returns true if processing queue should be stopped, otherwise false.

    def finished?
      return true if @number && @count >= @number

      @queue.empty? && @count > 0 &&
        (!@reader_thread || !@reader_thread.alive?)
    end


    ##
    # Immediately end all runner processing and threads.

    def kill
      stop_input!
      EM.stop if defined?(EM) && EM.reactor_running?
      @threads.each{|t| t.kill}
      @threads.clear
    end


    ##
    # Specify a block to run for a given trigger name.
    # Supported triggers are:
    # :complete:: Called after queue and input have been fully processed.
    # :input:: Called every time the queue needs populating.
    # :interrupt:: Called when SIGINT is captured.
    # :start:: Called before queue starts being processed.

    def on trigger_name, &block
      @triggers[trigger_name] = block
    end


    ##
    # Start processing the queue and reading from IO if available.
    #
    # Yields queue item until queue and io (if available) are empty and the
    # totaly number of requests to run is met (if number is set).

    def process_queue
      start_input!
      @count = 0

      until finished?
        @threads.delete_if{|t| !t.alive? }

        if @threads.length >= @concurrency || @queue.empty?
          Thread.pass
          next
        end

        @threads << Thread.new(@queue.shift) do |q_item|
          yield q_item if block_given?
        end

        @count += 1
      end

      @threads.each{|t| t.join}
      @threads.clear

      stop_input!
    end


    ##
    # Start processing the queue and reading from IO if available.
    #
    # Yields queue item until queue and io (if available) are empty and the
    # totaly number of requests to run is met (if number is set).
    #
    # Uses EventMachine to run asynchronously.
    #
    # Note: If the block given doesn't use EM, it will be blocking.
    #
    # TODO: Make input use EM from QueueRunner and Player IO.

    def process_queue_async &block
      require 'kronk/async' unless defined?(EM::HttpRequest)

      start_input!

      @count = 0

      EM.run do
        EM.add_periodic_timer do
          if finished?
            next if EM.connection_count > 0
            kill
          end

          if @queue.empty? || EM.connection_count >= @concurrency
            Thread.pass
            next
          end

          yield @queue.shift
          @count += 1
        end
      end
    end


    ##
    # Runs the queue and reads from input until it's exhausted or
    # @number is reached. Yields a queue item and a mutex when to passed
    # block:
    #
    #   runner = QueueRunner.new :concurrency => 10
    #   runner.queue.concat %w{item1 item2 item3}
    #
    #   runner.run do |q_item, mutex|
    #     # This block is run in its own thread.
    #     mutex.synchronize{ do_something_with q_item }
    #   end
    #
    # Calls the :start trigger before execution begins, calls :complete
    # when the execution has ended or is interrupted, also calls :interrupt
    # when execution is interrupted.

    def run
      trap 'INT' do
        kill
        trigger :complete
        trigger :interrupt
      end

      trigger :start

      method = self.class.async ? :process_queue_async : :process_queue

      send method do |q_item|
        yield q_item, @mutex if block_given?
      end

      trigger :complete
    end


    ##
    # Attempt to fill the queue by reading from the IO instance.
    # Starts a new thread and returns the thread instance.

    def start_input!
      return unless @triggers[:input]

      max_queue_size = @concurrency * 2

      @reader_thread = Thread.new do
        begin
          loop do
            if @queue.length >= max_queue_size
              Thread.pass
              next
            end

            Thread.exclusive do
              while @queue.length < max_queue_size
                @queue << trigger(:input)
              end
            end
            Thread.pass
          end

        rescue => e
          Thread.main.raise e
        end
      end
    end


    ##
    # Permanently stop input reading by killing the reader thread for a given
    # QueueRunner#run or QueueRunner#process_queue session.

    def stop_input!
      Thread.pass
      @reader_thread && @reader_thread.kill
    end


    ##
    # Run a previously defined callback. See QueueRunner#on.

    def trigger name
      t = @triggers[name]
      t && t.call
    end
  end
end
