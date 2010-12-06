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
      resp.instance_variable_set "@read", true
      resp.instance_variable_set "@socket", true

      resp.instance_variable_set "@body", resp.raw.split("\r\n\r\n",2)[1] if
        !resp.body

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
      # Returns the body data parsed according to the content type.
      # If no parser is given will look for the default parser based on
      # the Content-Type, or will return the cached parsed body if available.

      def parsed_body parser=nil
        return @parsed_body if @parsed_body && !parser
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
          [*include_headers].each do |h|
            headers.delete h
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


      def selective_string options={}
        str = self.body unless options[:no_body]

        if options[:compare_headers]
          header = raw_header(options[:compare_headers])
          str = [header, str].compact.join "\r\n\r\n"
        end

        str
      end


      def selective_data options={}
        data = nil

        unless options[:no_body]
          ds = DataSet.new parsed_body

          ds.collect_data_points options[:only_data]  if options[:only_data]
          ds.delete_data_points options[:ignore_data] if options[:ignore_data]

          data = ds.data
        end

        if options[:compare_headers]
          data = [parsed_header(options[:compare_headers]), data].compact
        end

        data
      end
    end
  end


  ##
  # Mock response object without a header for body-only http responses.

  class HeadlessResponse

    include Response::Helpers

    attr_accessor :body, :code

    def initialize body
      @body = body
      @raw  = body
      @header = {}
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
