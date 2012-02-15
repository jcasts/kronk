class Kronk

  ##
  # Outputs Player requests and results in a test-suite like format.

  class Player::Suite < Player

    def start
      @results = []
      @current = nil
      $stdout.puts "Started"

      @old_info_trap =
        trap 29 do
          @stop_time = Time.now
          @mutex.synchronize do
            render
            $stdout.puts "Elapsed:  #{(Time.now - @start_time).round 3}s"

            req = @current.responses[-1].request ||
                  @current.responses[0].request  if @current

            if req
              meth = req.http_method
              path = req.uri.request_uri
              time = req.response.time.round 3
              $stdout.puts "Current Req: #{meth} #{path} (#{time}s)"
            end
          end
        end
    end


    def result kronk
      status = "."

      result =
        if kronk.diff
          status = "F"             if kronk.diff.any?
          text   = diff_text kronk if status == "F"
          time   =
            (kronk.responses[0].time.to_f + kronk.responses[1].time.to_f) / 2

          [status, time, text]

        elsif kronk.response
          begin
            # Make sure response is parsable
            kronk.response.parsed_body if kronk.response.parser
          rescue => e
            error e, kronk
            return
          end if kronk.response.success?

          status = "F"             if !kronk.response.success?
          text   = resp_text kronk if status == "F"
          [status, kronk.response.time, text]
        end

      @mutex.synchronize do
        @current = kronk
        @results << result
      end

      $stdout << status
      $stdout.flush
    end


    def error err, kronk=nil
      status = "E"
      result = [status, 0, error_text(err, kronk)]
      @mutex.synchronize{ @results << result }

      $stdout << status
      $stdout.flush
    end


    def complete
      trap 29, @old_info_trap
      $stdout.puts "\nFinished in #{Time.now - @start_time} seconds.\n"
      render
    end


    def render
      player_time   = @stop_time - @start_time
      total_time    = 0
      bad_count     = 0
      failure_count = 0
      error_count   = 0
      err_buffer    = ""

      @results.each do |(status, time, text)|
        case status
        when "F"
          total_time    += time.to_f
          bad_count     += 1
          failure_count += 1
          err_buffer << "\n  #{bad_count}) Failure:\n#{text}"

        when "E"
          bad_count   += 1
          error_count += 1
          err_buffer << "\n  #{bad_count}) Error:\n#{text}"

        else
          total_time += time.to_f
        end
      end

      non_error_count = @results.length - error_count

      avg_time = non_error_count > 0 ? total_time / non_error_count  : "n/a"
      avg_qps  = non_error_count > 0 ? non_error_count / player_time : "n/a"

      $stderr.puts err_buffer unless err_buffer.empty?
      $stdout.puts "\n#{@results.length} cases, " +
                   "#{failure_count} failures, #{error_count} errors"

      $stdout.puts "Avg Time: #{(avg_time * 1000).round 3}ms"
      $stdout.puts "Avg QPS:  #{avg_qps.round 3}"

      return bad_count == 0
    end


    private


    def resp_text kronk
      http_method = kronk.response.request ?
                    kronk.response.request.http_method :
                    "(FILE)"

      <<-STR
  Request: #{kronk.response.code} - #{http_method} \
#{kronk.response.uri}
  Options: #{kronk.options.inspect}
      STR
    end


    def diff_text kronk
      output = <<-STR
  Request: #{kronk.responses[0].code} - \
#{kronk.responses[0].request.http_method} \
#{kronk.responses[0].uri}
           #{kronk.responses[1].code} - \
#{kronk.responses[0].request.http_method} \
#{kronk.responses[1].uri}
  Options: #{kronk.options.inspect}
  Diffs: #{kronk.diff.count}
      STR
      output << "#{kronk.diff.to_s}\n" unless Kronk.config[:brief]
      output
    end


    def error_text err, kronk=nil
      str = "  #{err.class}: #{err.message}"

      if kronk
        str << "\n  Options: #{kronk.options.inspect}\n"
      else
        str << "\n #{err.backtrace}\n"
      end

      str
    end
  end
end
