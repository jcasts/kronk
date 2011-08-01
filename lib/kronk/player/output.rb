class Kronk

  ##
  # Generic base class to inherit from for creating a player output.

  class Player::Output

    ##
    # New instance initializes @player and @start_time

    def initialize player
      @player     = player
      @start_time = Time.now
    end


    ##
    # Called right before the queue starts being processed.
    # Sets @start_time to Time.now.

    def start
      @start_time = Time.now
    end


    ##
    # Called after kronk was run without errors.

    def result kronk, mutex=nil
    end


    ##
    # Called if an error was raised while running kronk.

    def error err, kronk=nil, mutex=nil
    end


    ##
    # Called after the queue is done being processed.

    def completed
    end
  end
end
