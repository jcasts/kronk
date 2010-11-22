class Kronk

  ##
  # Wrapper to add a few niceties to the Net::HTTPResponse class.

  class Response < Net::HTTPResponse

    ##
    # Create a new Response instance from an IO object.

    def self.read_new io
      io   = Net::BufferedIO.new io unless Net::BufferedIO === io
      resp = super io

      resp.reading_body io, true do;end
      resp.instance_variable_set "@socket", io

      resp.extend Helpers
    end


    ##
    # Helper methods for Net::HTTPResponse objects.

    module Helpers

      ##
      # Returns the IO object used for the socket.

      def socket_io
        @socket.instance_variable_get "@io"
      end


      ##
      # Returns the raw http response.

      def raw
        io       = socket_io.dup
        raw_resp = ""
        max_pos  = io.pos

        io.rewind

        while io.pos < max_pos
          raw_resp << io.getc
        end

        raw_resp
      end


      ##
      # Returns the header portion of the raw http response.

      def raw_header
        raw.split("\r\n\r\n", 2)[0]
      end
    end
  end
end
