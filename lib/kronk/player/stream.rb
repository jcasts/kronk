class Kronk

  ##
  # Outputs Player results as a stream of Kronk outputs
  # in chunked form, each chunk being one response and the number
  # of octets being expressed in hexadecimal form.
  #
  #   out   = Player::StreamOutput.new
  #
  #   io1   = StringIO.new "this is the first chunk"
  #   io2   = StringIO.new "this is the rest"
  #
  #   kronk = Kronk.new
  #   kronk.request io1
  #   out.result kronk
  #   #=> "17\r\nthis is the first chunk\r\n"
  #
  #   kronk.request io2
  #   out.result kronk
  #   #=> "10\r\nthis is the rest\r\n"
  #
  # Note: This output class will not render errors.

  class Player::Stream < Player

    def result kronk
      output =
        if kronk.diff
          kronk.diff.formatted

        elsif kronk.response
          kronk.response.stringify
        end

      return unless output && !output.empty?

      @mutex.synchronize do
        $stderr << "#{"%X" % output.length}\r\n"
        $stdout << output
        $stderr << "\r\n"
      end

      output
    end


    def completed
      $stderr << "0\r\n\r\n"
      $stderr.flush
      $stdout.flush
      true
    end
  end
end
