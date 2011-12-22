class Kronk

  ##
  # Outputs player request and response metrics as a tab seperated values.

  class Player::TSV < Player

    def start
      @total_bytes = 0

      $stderr.puts %w{
        time
        resp_time(ms)
        bytes
        bps
        qps
        code
        scheme
        host
        port
        path
      }.join("\t")
    end


    def result kronk
      suite_time = Time.now - @start_time
      qps = (@count / suite_time).round(3)

      kronk.responses.each do |resp|
        @mutex.synchronize{ @total_bytes += resp.total_bytes }
        req_time = (Time.now - resp.time).to_i

        $stdout.puts [
          req_time,
          (resp.time * 1000).round,
          resp.bytes,
          (@total_bytes / suite_time).round,
          qps,
          resp.code,
          resp.uri.scheme,
          resp.uri.host,
          resp.uri.port,
          resp.uri.path
        ].join("\t")
      end
    end
  end
end
