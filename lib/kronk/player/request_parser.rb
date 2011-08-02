class Kronk

  ##
  # Stream-friendly HTTP Request parser for piping into the Kronk player.
  #

  class Player::RequestParser

    def initialize string_or_io=nil
      @buffer = []
      @io     = string_or_io
      @io     = StringIO.new(@io) if String === @io
    end


    ##
    # Parse the next request in the IO instance.

    def get_next
      return if !@io || @io.eof? && @buffer.empty?

      @buffer << @io.gets if @buffer.empty?

      line = ""
      until line =~ Request::REQUEST_LINE_MATCHER || @io.eof?
        @buffer << (line = @io.gets)
      end

      str = @io.eof? ? @buffer.join : @buffer.slice!(0..-2).join
      parse str
    end


    ##
    # Parse a single http request.

    def parse string
      Request.parse_to_hash string
    end
  end
end
