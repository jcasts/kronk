class Kronk

  ##
  # Outputs Player requests and results in a test-suite like format.

  class Player::SuiteOutput

    attr_accessor :player_time

    def initialize
      @results     = []
      @player_time = 0
    end


    def result kronk
      status = "."

      @results <<
        if kronk.diff
          status = "F"             if kronk.diff.count > 0
          text   = diff_text kronk if status == "F"
          time   =
            (kronk.responses[0].time.to_f + kronk.responses[1].time.to_f) / 2

          [status, time, text]

        elsif kronk.resp
          status = "F"             if !kronk.response.success?
          text   = resp_text kronk if status == "F"
          [status, kronk.response.time, text]
        end

      $stdout << status
      $stdout.flush
    end


    def error err, kronk=nil
      @results << ["E", 0, error_text(err, kronk)]
    end


    def completed
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
          err_buffer << "  #{bad_count}) Failure:\n#{text}"

        when "E"
          bad_count   += 1
          error_count += 1
          err_buffer << "  #{bad_count}) Error:\n#{text}"

        else
          total_time += time.to_f
        end
      end

      non_error_count = @results.length - error_count

      avg_time = total_time / non_error_count

      $stdout.puts "\nFinished in #{@player_time} seconds.\n\n"
      $stderr.puts err_buffer
      $stdout.puts "#{@results.length} cases, " +
                   "#{failure_count} failures, #{error_count} errors"

      $stdout.puts "Avg Time: #{avg_time}"
      $stdout.puts "Avg QPS: #{non_error_count / @player_time}"

      return bad_count == 0
    end


    private


    def resp_text kronk
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


    def error_text err, kronk=nil
      str = "#{err.class}: #{err.message}"

      if kronk
        str << "\n  Options: #{kronk.options.inspect}"
      else
        str << "\n #{err.backtrace}"
      end

      str
    end
  end
end
