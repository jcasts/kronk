class Kronk

  ##
  # A basic queue and input processor that runs multi-threaded.
  #
  # Input is optional and specified by creating an input trigger
  # (passing a block to on(:input)).
  # Input will be used to fill queue as the queue gets depleted by
  # being processed.
  #
  #   qrunner = QueueRunner.new
  #   qrunner.concurrency = 20  # thread count
  #   qrunner.number = 100      # process 100 queue items
  #
  #   file = File.open "example.log", "r"
  #
  #   qrunner.on :input do
  #     if file.eof?
  #       qrunner.finish
  #     else
  #       file.readline
  #     end
  #   end
  #
  #   qrunner.on :complete do
  #     file.close
  #     puts "DONE!"
  #   end
  #
  #   # If running in multi-threaded mode, item mutex will also be passed
  #   # as optional second argument.
  #   qrunner.run do |queue_item|
  #     # Do something with item.
  #   end
  #
  # Additionally, the :interrupt trigger may be used to handle behavior when
  # SIGINT is sent to the process.
  #
  #   qrunner.on :interrupt do
  #     qrunner.kill
  #     puts "Caught SIGINT"
  #     exit 1
  #   end
  #
  # The :result trigger may also be used to
  # perform actions with the return value of the block given to QueueRunner#run.
  # This is useful for post-processing data without affecting concurrency as
  # it will be run in a separate thread.
  #
  #   qrunner.on :result do |result|
  #     p result
  #   end

  class QueueRunner

    attr_accessor :number, :queue, :count, :threads, :reader_thread

    ##
    # Create a new QueueRunner for batch multi-threaded processing.
    # Supported options are:
    # :number:: Fixnum - Total number of items to process

    def initialize opts={}
      @number   = opts[:number]
      @count    = 0
      @queue    = []
      @threads  = []
      @rthreads = []

      @max_queue_size = 100

      @reader_thread = nil

      @triggers = {}

      @qmutex = Mutex.new
    end


    ##
    # Returns true if processing queue should be stopped, otherwise false.

    def finished?
      return true if @number && @count >= @number

      @queue.empty? && @count > 0 &&
        (!@reader_thread || !@reader_thread.alive?)
    end


    ##
    # Stop runner processing gracefully.

    def finish
      stop_input!

      @threads.each do |t|
        @rthreads << Thread.new(t.value){|value| trigger :result, value }
      end

      @rthreads.each(&:join)

      @threads.clear
      @rthreads.clear
    end


    ##
    # Immediately end all runner processing and threads.

    def kill
      stop_input!
      @threads.each{|t| t.kill}
      @rthreads.each{|t| t.kill}
      @threads.clear
      @rthreads.clear
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
    # Process the queue and read from IO if available.
    #
    # Yields queue item until queue and io (if available) are empty and the
    # totaly number of requests to run is met (if number is set).

    def concurrently concurrency=1, &block
      @max_queue_size = concurrency * 2

      until_finished do |count, active_count|
        if active_count >= concurrency || @queue.empty?
          Thread.pass
          next
        end

        num_threads = smaller_count(concurrency - active_count)

        num_threads.times do
          yield_queue_item(&block)
        end
      end
    end


    ##
    # Process the queue with periodic timer and a given period in seconds.
    #
    # Yields queue item until queue and io (if available) are empty and the
    # totaly number of requests to run is met (if number is set).
    #
    # If clump is given, will fire clump number of requests at a time, which
    # can modify how often requests are send. The overall period should however
    # be close to the one specified.

    def periodically period=0.01, clump=1, &block
      @max_queue_size = 0.5 / period
      @max_queue_size = clump * 2 if @max_queue_size < (clump * 2)

      sleep_period = period * clump if clump

      start = Time.now

      until_finished do |count, active_count|
        num_threads    = 1
        expected_count = ((Time.now - start) / period).ceil

        if count < expected_count
          num_threads = smaller_count(expected_count - count)
        else
          sleep sleep_period
        end

        num_threads.times do
          yield_queue_item(&block)
        end
      end
    end



    ##
    # Loop and read from input continually until finished.
    # Yields total_count and active_count if passed a block.

    def until_finished
      old_trap = trap 'INT' do
        @stop_time = Time.now
        kill
        trigger(:interrupt)
        trap 'INT', old_trap
        Process.kill 'INT', Process.pid
      end

      @start_time = Time.now

      trigger :start

      start_input!
      @count = 0

      until finished?
        @rthreads.delete_if{|t| !t.alive? && t.join }

        results = []
        @threads.delete_if do |t|
          !t.alive? &&
            results << t.value
        end

        @rthreads << Thread.new(results) do |values|
          values.each{|value| trigger :result, value }
        end unless results.empty?

        yield @count, @threads.count if block_given?
      end

      @stop_time = Time.now

      finish

      trigger :complete
    end


    ##
    # Shifts one item off the queue and yields it to the given block.

    def yield_queue_item
      until item = @qmutex.synchronize{ @queue.shift } or !@reader_thread.alive?
        Thread.pass
      end

      return unless item

      @threads << Thread.new(item) do |q_item|
        yield q_item if block_given?
      end

      @threads.last.abort_on_exception = true

      @count += 1
    end


    ##
    # Attempt to fill the queue by reading from the IO instance.
    # Starts a new thread and returns the thread instance.

    def start_input! max_queue=@max_queue_size
      return unless @triggers[:input]

      @reader_thread = Thread.new do
        begin
          loop do
            if max_queue && @queue.length >= max_queue
              Thread.pass
              next
            end

            while !max_queue || @queue.length < max_queue
              item = trigger(:input)
              @qmutex.synchronize{ @queue << item }
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

    def trigger name, *args
      t = @triggers[name]
      t && t.call(*args)
    end


    private

    def smaller_count num
      @number && (@number - count < num) ? (@number - count) : num
    end
  end
end
