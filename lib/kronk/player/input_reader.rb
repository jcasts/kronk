class Kronk

  ##
  # Reads an IO stream and parses it with the given parser.
  # Parser must respond to the following:
  # * start_new?(line) - Returns true when line is the beginning of a new
  #   http request.
  # * parse(str) - Parses the raw string into value Kronk#request options.

  class Player::InputReader

    attr_accessor :io, :parser

    def initialize string_or_io, parser=nil
      @buffer = []
      @parser = parser || Kronk::Player::RequestParser
      @io     = string_or_io
      @io     = StringIO.new(@io) if String === @io
    end


    ##
    # Parse the next request in the IO instance.

    def get_next
      return if eof?

      @buffer << @io.gets if @buffer.empty?

      line = ""
      until @parser.start_new?(line) || @io.eof?
        @buffer << (line = @io.gets)
      end

      end_index = @io.eof? ? -1 : -2
      @parser.parse @buffer.slice!(0..end_index).join
    end


    ##
    # Returns true if there is no more input to read from.

    def eof?
      !@io || (@io.closed? || @io.eof?) && @buffer.empty?
    end
  end
end
