class Kronk

  ##
  # Simple JSON Yajl wrapper to support Kronk's parser interface.

  class JsonParser

    ##
    # Parse JSON from a String or IO. Yields parsed JSON documents to
    # block if provided. Useful for streaming APIs.

    def self.parse str_or_io, &block
      data   = nil
      socket = str_or_io.respond_to?(:read) ?
                str_or_io : StringIO.new(str_or_io)

      parse_io socket do |d|
        data = d
        yield d if d && block_given?
      end

      data || raise(ParserError, "invalid JSON")

    rescue RuntimeError
      raise ParserError, "unparsable JSON"
    end


    ##
    # Parse JSON from an IO object. Each document is yielded to the given block.

    def self.parse_io socket, &block
      parser = Yajl::Parser.new
      parser.on_parse_complete = block

      while !socket.eof? && (line = socket.gets)
        next if line == "\r\n"
        parser << line
      end
    end
  end
end

JSON = Kronk::JsonParser
