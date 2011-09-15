class Kronk

  ##
  # Stream-friendly HTTP Request parser for piping into the Kronk player.
  # Uses Kronk::Request for parsing.

  class Player::RequestParser

    ##
    # Returns true-ish if the line given is the start of a new request.

    def self.start_new? line
      line =~ Request::REQUEST_LINE_MATCHER
      # Make sure we have a host ($2) or path ($3) before proceeding.
      !!($2 || $3)
    end


    ##
    # Parse a single http request kronk options hash.

    def self.parse string
      Kronk::Request.parse_to_hash string
    end
  end
end
