class Kronk

  ##
  # Outputs Player requests and results as a stream of Kronk outputs
  # separated by the null character \\000.
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

      $stdout << output << "\0"
      $stdout.flush
    end
  end
end
