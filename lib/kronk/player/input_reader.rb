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
      @io_buf = ""
      @buffer = []
      @parser = parser || Kronk::Player::RequestParser
      @io     = string_or_io
      @io     = StringIO.new(@io) if String === @io
    end


    ##
    # Parse the next request in the IO instance.

    def get_next
      return if eof?

      @buffer << gets if @buffer.empty?

      until @io.eof? && @io_buf.empty?
        line = gets
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
    # Read one line from @io, thread-non-blocking.

    def gets
      return @io.gets if StringIO === @io

      next_line = io_buf_line
      return next_line if next_line

      until @io.eof?
        selected, = select [@io], nil, nil, 0.05

        if selected.nil? || selected.empty?
          Thread.pass
          next
        end

        @io_buf << @io.readpartial(1024)

        next_line = io_buf_line
        return next_line if next_line
      end
    end


    ##
    # Get the first line of the io buffer.

    def io_buf_line
      index = @io_buf.index "\n"
      return unless index

      @io_buf.slice!(0..index)
    end


    ##
    # Returns true if there is no more input to read from.

    def eof?
      !@io || (@io.closed? || @io.eof?) && @buffer.empty?
    end
  end
end
