class Kronk

  ##
  # Returns benchmarks for a set of Player results.
  # * Total time taken
  # * Complete requests
  # * Failed requests
  # * Total bytes transferred
  # * Requests per second
  # * Time per request
  # * Transfer rate
  # * Connection times (min mean median max)
  # * Percentage of requests within a certain time
  # * Slowest endpoints

  class Player::Benchmark < Player

    class ResultSet

      attr_accessor :total_time, :err_count

      attr_reader :byterate, :count, :fastest, :precision,
                  :slowest, :total_bytes

      def initialize
        @times     = Hash.new(0)
        @count     = 0
        @r5XX      = 0
        @r4XX      = 0
        @r3XX      = 0
        @err_count = 0

        @precision = 3

        @slowest = nil
        @fastest = nil

        @paths = {}

        @total_bytes = 0
        @byterate    = 0

        @total_time = 0
      end


      def add_result resp
        time = (resp.time * 1000).round

        @times[time] += 1
        @count += 1

        case resp.code[0, 1]
        when "5" then @r5XX += 1
        when "4" then @r4XX += 1
        when "3" then @r3XX += 1
        end

        @slowest = time if !@slowest || @slowest < time
        @fastest = time if !@fastest || @fastest > time

        log_req resp.request, time if resp.request

        @total_bytes += resp.total_bytes

        @byterate = (@byterate * (@count-1) + resp.byterate) / @count
      end


      def log_req req, time
        uri = req.uri.dup
        uri.query = nil
        uri = "#{req.http_method} #{uri.to_s}"

        @paths[uri] ||= [0, 0]
        pcount = @paths[uri][1] + 1
        @paths[uri][0] = (@paths[uri][0] * @paths[uri][1] + time) / pcount
        @paths[uri][1] = pcount

        clean_req_log
      end


      def clean_req_log
        if @paths.length > 500
          order_reqs[500..-1].each{|(uri,_)| @paths.delete uri }
        end
      end


      def deviation
        return 0 if @count == 0
        return @deviation if @deviation

        mdiff = @times.to_a.inject(0) do |sum, (time, count)|
                  sum + ((time-self.mean)**2) * count
                end

        @deviation = ((mdiff / @count)**0.5).round @precision
      end


      def mean
        return 0 if @count == 0
        @mean ||= (self.sum / @count).round @precision
      end


      def median
        return 0 if @count == 0
        @median ||= ((@slowest + @fastest) / 2).round @precision
      end


      def percentages
        return @percentages if @percentages

        @percentages = {}

        perc_list   = [50, 66, 75, 80, 90, 95, 98, 99]
        times_count = 0
        target_perc = perc_list.first

        i = 0
        @times.keys.sort.each do |time|
          times_count += @times[time]

          if target_perc <= (100 * times_count / @count)
            @percentages[target_perc] = time
            i += 1
            target_perc = perc_list[i]

            break unless target_perc
          end
        end

        perc_list.each{|l| @percentages[l] ||= self.slowest }
        @percentages[100] = self.slowest
        @percentages
      end


      def req_per_sec
        return 0 if @count == 0
        (@count / @total_time).round @precision
      end


      def transfer_rate
        ((@total_bytes / 1000) / @total_time).round @precision
      end


      def sum
        @sum ||= @times.inject(0){|sum, (time,count)| sum + time * count}
      end


      def order_reqs
        @paths.to_a.sort{|x,y| y[1][0] <=> x[1][0]}
      end


      def slowest_reqs
        @slowest_reqs ||= order_reqs[0..9]
      end


      def clear_caches
        @percentages  = nil
        @slowest_reqs = nil
        @sum          = nil
        @mean         = nil
        @median       = nil
        @deviation    = nil
      end


      def to_s
        clear_caches

        out = <<-STR

Completed:     #{@count}
300s:          #{@r3XX}
400s:          #{@r4XX}
500s:          #{@r5XX}
Errors:        #{@err_count}
Req/Sec:       #{self.req_per_sec}
Total Bytes:   #{@total_bytes}
Transfer Rate: #{self.transfer_rate} Kbytes/sec

Connection Times (ms)
  Min:       #{self.fastest || 0}
  Mean:      #{self.mean}
  [+/-sd]:   #{self.deviation}
  Median:    #{self.median}
  Max:       #{self.slowest || 0}

Request Percentages (ms)
   50%    #{self.percentages[50]}
   66%    #{self.percentages[66]}
   75%    #{self.percentages[75]}
   80%    #{self.percentages[80]}
   90%    #{self.percentages[90]}
   95%    #{self.percentages[95]}
   98%    #{self.percentages[98]}
   99%    #{self.percentages[99]}
  100%    #{self.percentages[100]} (longest request)
        STR

        unless slowest_reqs.empty?
          out << "
Avg. Slowest Requests (ms, count)
#{slowest_reqs.map{|arr| "  #{arr[1].inspect}  #{arr[0]}"}.join "\n" }"
        end

        out
      end
    end


    def start
      @interactive = $stdout.isatty
      @res_count   = 0
      @results     = [ResultSet.new]
      @div         = @number / 10 if @number
      @div         = 100 if !@div || @div < 10
      @last_print  = Time.now
      @line_count  = 0

      puts "Benchmarking..." unless @interactive
    end


    def result kronk
      @mutex.synchronize do
        kronk.responses.each_with_index do |resp, i|
          @results[i] ||= ResultSet.new
          @results[i].add_result resp
        end

        @res_count += 1

        if @interactive
          render if Time.now - @last_print > 0.5
        else
          puts "#{@res_count} requests" if @res_count % @div == 0
        end
      end
    end


    def clear_screen
      $stdout.print "\e[2K\e[1A" * @line_count
    end


    def error err, kronk
      @mutex.synchronize do
        @res_count += 1
        @results.each do |res|
          res.err_count += 1
        end
      end
    end


    def complete
      puts "Finished!" unless @interactive

      render
      true
    end


    def render
      out         = "#{head}#{body}\n"
      new_count   = out.to_s.split("\n").length
      @last_print = Time.now
      clear_screen if @interactive
      @line_count = new_count
      $stdout.print out
      $stdout.flush
    end


    def body
      @results.each{|res| res.total_time = Time.now - @start_time }

      if @results.length > 1
        Diff.new(@results[0].to_s, @results[1].to_s, :context => false).
          formatted
      else
        @results.first.to_s
      end
    end


    def head
      <<-STR

Benchmark Time:      #{(Time.now - @start_time).to_f} sec
Number of Requests:  #{@count}
Concurrency:         #{@qps ? "#{@qps} qps" : @concurrency}
#{"Current Connections: #{Kronk::HTTP.conn_count}\n" if @interactive}\
Total Connections:   #{Kronk::HTTP.total_conn}
      STR
    end
  end
end


if Float.instance_method(:round).arity == 0
class Float
  undef round
  def round ndigits=0
    num, dec = self.to_s.split(".")
    num = "#{num}.#{dec[0,ndigits]}".sub(/\.$/, "")
    Float num
  end
end
end
