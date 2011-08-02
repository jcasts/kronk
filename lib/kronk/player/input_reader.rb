class Kronk

  ##
  # Reads an IO stream and parses it with the given parser.
  # Parser must respond to the following:
  # * start_new?(line) - Returns true when line is the beginning of a new
  #   http request.
  # * parse(str) - Parses the raw string into value Kronk#request options.

  class Player::InputReader

    def initialize string_or_io, parser=nil
      @buffer = []
      @parser = parser || RequestParser
      @io     = string_or_io
      @io     = StringIO.new(@io) if String === @io
    end


    ##
    # Parse the next request in the IO instance.

    def get_next
      return if @io.eof? && @buffer.empty?

      @buffer << @io.gets if @buffer.empty?

      line = ""
      until @parser.start_new?(line) || @io.eof?
        @buffer << (line = @io.gets)
      end

      str = @io.eof? ? @buffer.join : @buffer.slice!(0..-2).join
      @parser.parse str
    end
  end
end
