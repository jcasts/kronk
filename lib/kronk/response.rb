class Kronk

  ##
  # Wrapper to add a few niceties to the Net::HTTPResponse class.

  class Response < Net::HTTPResponse

    class MissingParser < Exception; end

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
      resp.set_helper_attribs socket_io, true, true

      resp
    end



    ##
    # Helper methods for Net::HTTPResponse objects.

    module Helpers

      ##
      # Read the raw response from a debug_output instance and return an array
      # containing the raw request, response, and number of bytes received.

      def read_raw_from debug_io
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
      # Instantiates helper attributes from the debug socket io.

      def set_helper_attribs socket_io, socket=nil, body_read=nil
        @raw      = udpate_encoding read_raw_from(socket_io)[1]

        @read     = body_read unless body_read.nil?
        @socket ||= socket
        @body   ||= @raw.split("\r\n\r\n",2)[1]

        udpate_encoding @body

        puts "#{@raw.length} - #{@body.length}" if
          @raw.length == 0 && @body.length != 0
        self
      end


      ##
      # Returns the encoding provided in the Content-Type header or
      # "binary" if charset is unavailable.
      # Returns "utf-8" if no content type header is missing.

      def encoding
        content_types = self.to_hash["content-type"]

        return "utf-8" if !content_types

        content_types.each do |c_type|
          return $2 if c_type =~ /(^|;\s?)charset=(.*?)\s*(;|$)/
        end

        "binary"
      end


      ##
      # Assigns self.encoding to the passed string if
      # it responds to 'force_encoding'.
      # Returns the string given with the new encoding.

      def udpate_encoding str
        str.force_encoding self.encoding if str.respond_to? :force_encoding
        str
      end


      ##
      # Returns the raw http response.

      def raw
        @raw
      end


      ##
      # Returns the body data parsed according to the content type.
      # If no parser is given will look for the default parser based on
      # the Content-Type, or will return the cached parsed body if available.

      def parsed_body parser=nil
        @parsed_body ||= nil

        return @parsed_body if @parsed_body && !parser

        if String === parser
          parser = Kronk.parser_for(parser) || Kronk.find_const(parser)
        end

        parser ||= Kronk.parser_for self['Content-Type']

        raise MissingParser,
          "No parser for Content-Type: #{self['Content-Type']}" unless parser

        @parsed_body = parser.parse self.body
      end


      ##
      # Returns the parsed header hash.

      def parsed_header include_headers=true
        headers = self.to_hash.dup

        case include_headers
        when nil, false
          nil

        when Array, String
          include_headers = [*include_headers].map{|h| h.to_s.downcase}

          headers.each do |key, value|
            headers.delete key unless
              include_headers.include? key.to_s.downcase
          end

          headers

        when true
          headers
        end
      end


      ##
      # Returns the header portion of the raw http response.

      def raw_header include_headers=true
        headers = "#{raw.split("\r\n\r\n", 2)[0]}\r\n"

        case include_headers
        when nil, false
          nil

        when Array, String
          includes = [*include_headers].join("|")
          headers.scan(%r{^((?:#{includes}): [^\n]*\n)}im).flatten.join

        when true
          headers
        end
      end


      ##
      # Returns the raw response with selective headers and/or the body of
      # the response. Supports the following options:
      # :no_body:: Bool - Don't return the body; default nil
      # :with_headers:: Bool/String/Array - Return headers; default nil

      def selective_string options={}
        str = self.body unless options[:no_body]

        if options[:with_headers]
          header = raw_header(options[:with_headers])
          str = [header, str].compact.join "\r\n"
        end

        str
      end


      ##
      # Returns the parsed response with selective headers and/or the body of
      # the response. Supports the following options:
      # :no_body:: Bool - Don't return the body; default nil
      # :with_headers:: Bool/String/Array - Return headers; default nil
      # :parser:: Object - The parser to use for the body; default nil
      # :ignore_data:: String/Array - Removes the data from given data paths
      # :only_data:: String/Array - Extracts the data from given data paths

      def selective_data options={}
        data = nil

        unless options[:no_body]
          data = parsed_body options[:parser]
        end

        if options[:with_headers]
          data = [parsed_header(options[:with_headers]), data].compact
        end

        Path::Transaction.run data, options do |t|
          t.select(*options[:only_data])
          t.delete(*options[:ignore_data])
        end
      end
    end
  end


  ##
  # Mock response object without a header for body-only http responses.

  class HeadlessResponse

    include Response::Helpers

    attr_accessor :body, :code

    def initialize body, file_ext=nil
      @body = body
      @raw  = body

      encoding = body.encoding rescue "UTF-8"

      @header = {
        'Content-Type' => ["#{file_ext}; charset=#{encoding}"]
      }
    end


    ##
    # Interface method only. Returns nil for all but content type.

    def [] key
      @header[key]
    end

    def []= key, value
      @header[key] = value
    end


    ##
    # Interface method only. Returns empty hash.

    def to_hash
      Hash.new
    end
  end
end
