class Kronk

  ##
  # Outputs Player requests and results in a test-suite like format.

  class Player::Suite < Player

    def start
      @results    = []
      $stdout.puts "Started"
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

      @mutex.synchronize{ @results << result }

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
      suite_time    = Time.now - @start_time
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

      $stdout.puts "\nFinished in #{suite_time} seconds.\n"
      $stderr.puts err_buffer unless err_buffer.empty?
      $stdout.puts "\n#{@results.length} cases, " +
                   "#{failure_count} failures, #{error_count} errors"

      $stdout.puts "Avg Time: #{avg_time}"
      $stdout.puts "Avg QPS: #{avg_qps}"

      return bad_count == 0
    end


    private


    def resp_text kronk
      <<-STR
  Request: #{kronk.response.code} - #{kronk.response.request.http_method} \
#{kronk.response.uri}
  Options: #{kronk.options.inspect}
      STR
    end


    def diff_text kronk
      <<-STR
  Request: #{kronk.responses[0].code} - \
#{kronk.responses[0].request.http_method} \
#{kronk.responses[0].uri}
           #{kronk.responses[1].code} - \
#{kronk.responses[0].request.http_method} \
#{kronk.responses[1].uri}
  Options: #{kronk.options.inspect}
  Diffs: #{kronk.diff.count}
      STR
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
