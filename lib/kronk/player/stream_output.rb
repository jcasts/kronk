class Kronk

  ##
  # Outputs Player requests and results as a stream of Kronk outputs
  # separated by the null character \\000.
  #
  # Note: This output class will not render errors.

  class Player::StreamOutput

    def initialize
      @results    = []
      @start_time = Time.now
    end


    def start
      @start_time = Time.now
    end


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


    def error err, kronk=nil
    end


    def completed
    end
  end
end
