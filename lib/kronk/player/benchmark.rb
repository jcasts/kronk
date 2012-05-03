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

      attr_accessor :total_time

      attr_reader :byterate, :count, :fastest, :precision,
                  :slowest, :total_bytes, :err_count

      def initialize
        @times     = Hash.new(0)
        @count     = 0
        @r5XX      = 0
        @r4XX      = 0
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

        @r5XX += 1 if resp.code =~ /^5\d\d$/
        @r4XX += 1 if resp.code =~ /^4\d\d$/

        @slowest = time if !@slowest || @slowest < time
        @fastest = time if !@fastest || @fastest > time

        log_req resp.request, time if resp.request

        @total_bytes += resp.raw.bytes.count

        @byterate = (@byterate * (@count-1) + resp.byterate) / @count
      end


      def log_req req, time
        uri = req.uri.dup
        uri.query = nil
        uri = "#{req.http_method} #{uri.to_s}"

        # TODO: Keep the number in @paths to 10.
        @paths[uri] ||= [0, 0]
        pcount = @paths[uri][1] + 1
        @paths[uri][0] = (@paths[uri][0] * @paths[uri][1] + time) / pcount
        @paths[uri][0] = @paths[uri][0].round @precision
        @paths[uri][1] = pcount
      end


      def deviation
        return @deviation if @deviation

        mdiff = @times.to_a.inject(0) do |sum, (time, count)|
                  sum + ((time-self.mean)**2) * count
                end

        @deviation = ((mdiff / @count)**0.5).round @precision
      end


      def mean
        @mean ||= (self.sum / @count).round @precision
      end


      def median
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
        (@count / @total_time).round @precision
      end


      def transfer_rate
        ((@total_bytes / 1000) / @total_time).round @precision
      end


      def sum
        @sum ||= @times.inject(0){|sum, (time,count)| sum + time * count}
      end


      def slowest_reqs
        @slowest_reqs ||= @paths.to_a.sort{|x,y| y[1] <=> x[1]}[0..9]
      end


      def to_s
        out = <<-STR

Completed:     #{@count}
400s:          #{@r4XX}
500s:          #{@r5XX}
Errors:        #{@err_count}
Req/Sec:       #{self.req_per_sec}
Total Bytes:   #{@total_bytes}
Transfer Rate: #{self.transfer_rate} Kbytes/sec

Connection Times (ms)
  Min:       #{self.fastest}
  Mean:      #{self.mean}
  [+/-sd]:   #{self.deviation}
  Median:    #{self.median}
  Max:       #{self.slowest}

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
      @res_count = 0
      @results   = []
      @div       = @number / 10 if @number
      @div       = 100 if !@div || @div < 10
      puts "Benchmarking..."
    end


    def result kronk
      @mutex.synchronize do
        kronk.responses.each_with_index do |resp, i|
          @results[i] ||= ResultSet.new
          @results[i].add_result resp
        end

        @res_count += 1
        puts "#{@res_count} requests" if @res_count % @div == 0
      end
    end


    def error err, kronk
      @mutex.synchronize do
        @res_count += 1
        @results.each do |res|
          @err_count += 1
        end
      end
    end


    def complete
      puts "Finished!"

      render_head
      render_body

      true
    end


    def render_body
      @results.each{|res| res.total_time = @stop_time - @start_time }

      if @results.length > 1
        puts Diff.new(@results[0].to_s, @results[1].to_s).formatted
      else
        puts @results.first.to_s
      end
    end


    def render_head
      puts <<-STR

Benchmark Time:      #{(Time.now - @start_time).to_f} sec
Number of Requests:  #{@count}
Concurrency:         #{@qps ? "#{@qps} qps" : @concurrency}
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
