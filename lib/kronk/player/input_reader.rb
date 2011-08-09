class Kronk

  ##
  # Reads an IO stream and parses it with the given parser.
  # Parser must respond to the following:
  # * start_new?(line) - Returns true when line is the beginning of a new
  #   http request.
  # * parse(str) - Parses the raw string into value Kronk#request options.

  class Player::InputReader

    attr_accessor :io, :parser, :buffer

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

      until @io.eof?
        line = @io.gets
        next unless line

        if @parser.start_new?(line) || @buffer.empty?
          @buffer << line
          break
        else
          @buffer.last << line
        end
      end

      return if @buffer.empty?
      @parser.parse(@buffer.slice!(0)) || self.get_next
    end


    ##
    # Returns true if there is no more input to read from.

    def eof?
      !@io || (@io.closed? || @io.eof?) && @buffer.empty?
    end
  end
end
