class Kronk

  ##
  # Wrapper to add a few niceties to the Net::HTTPResponse class.

  class Response < Net::HTTPResponse

    ##
    # Create a new Response instance from an IO object.

    def self.read_new io
      io = Net::BufferedIO.new io unless Net::BufferedIO === io
      io.debug_output = socket_io = StringIO.new

      begin
        resp = super io
        resp.reading_body io, true do;end
      rescue EOFError
      end

      resp.extend Helpers

      r_req, r_resp, r_bytes = read_raw_from socket_io
      resp.instance_variable_set "@raw", r_resp

      resp
    end


    ##
    # Read the raw response from a debug_output instance and return an array
    # containing the raw request, response, and number of bytes received.

    def self.read_raw_from debug_io
      req = nil
      resp = ""
      bytes = nil

      debug_io.rewind
      output = debug_io.read.split "\n"

      if output.first =~ %r{<-\s(.*)}
        req = instance_eval $1
        output.delete_at 0
      end

      if output.last =~ %r{read (\d+) bytes}
        bytes = $1.to_i
        output.delete_at(-1)
      end

      output.map do |line|
        next unless line[0..2] == "-> "
        resp << instance_eval(line[2..-1])
      end

      [req, resp, bytes]
    end


    ##
    # Helper methods for Net::HTTPResponse objects.

    module Helpers

      ##
      # Returns the raw http response.

      def raw
        @raw
      end


      ##
      # Returns the header portion of the raw http response.

      def raw_header
        raw.split("\r\n\r\n", 2)[0]
      end
    end
  end
end
