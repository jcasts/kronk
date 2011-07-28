class Kronk

  ##
  # Outputs Player results as a stream of Kronk outputs
  # in chunked form, each chunk being one response and the number
  # of octets being expressed in plain decimal form.
  #
  #   "23\r\nthis is the first chunk\r\n"
  #
  # Note: This output class will not render errors.

  class Player::StreamOutput < Player::Output

    def result kronk
      output =
        if kronk.diff
          kronk.diff.formatted

        elsif kronk.response
          kronk.response.stringify kronk.options
        end

      output = "#{output.length}\r\n#{output.length}\r\n"
      $stdout << output
      $stdout.flush
    end
  end
end
