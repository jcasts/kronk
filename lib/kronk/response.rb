class Kronk

  ##
  # Standard Kronk response object.

  class Response

    class MissingParser < Kronk::Exception; end
    class InvalidParser < Kronk::Exception; end


    ENCODING_MATCHER = /(^|;\s?)charset=(.*?)\s*(;|$)/

    ##
    # Read http response from a file and return a Kronk::Response instance.

    def self.read_file path
      file = File.open(path, "rb")
      resp = new file
      file.close

      resp
    end


    attr_accessor :body, :code, :raw, :request, :stringify_opts, :time

    alias to_s raw

    ##
    # Create a new Response object from a String or IO.

    def initialize io=nil, request=nil
      io ||= ""

      @raw = ""

      @io = String === io ? StringIO.new(io) : io

      @_res = response_from_io @io

      @headers = @encoding = @parser = nil

      @time = 0

      @raw = try_force_encoding @raw

      @request = request

      @body   = try_force_encoding(@_res.body) if @_res.body
      @body ||= @raw.split("\r\n\r\n",2)[1]

      @code = @_res.code

      @stringify_opts = {}
    end


    ##
    # Accessor for the HTTPResponse instance []

    def [] key
      @_res[key]
    end


    ##
    # Accessor for the HTTPResponse instance []

    def []= key, value
      @_res[key] = value
    end


    ##
    # If time was set, returns bytes-per-second for the whole response,
    # including headers.

    def byterate
      return 0 unless @raw && @time.to_f > 0
      @byterate = self.total_bytes / @time.to_f
    end


    ##
    # Size of the body in bytes.

    def bytes
      (headers["content-length"] || @body.bytes.count).to_i
    end


    ##
    # Cookie header accessor.

    def cookie
      @_res['Cookie']
    end


    ##
    # Return the Ruby-1.9 encoding of the body, or String representation
    # for Ruby-1.8.

    def encoding
      return @encoding if @encoding
      @encoding = "utf-8" unless headers["content-type"]
      c_type = headers["content-type"] =~ ENCODING_MATCHER
      @encoding = $2 if c_type
      @encoding ||= "ASCII-8BIT"
      @encoding = Encoding.find(@encoding) if defined?(Encoding)
      @encoding
    end


    ##
    # Force the encoding of the raw response and body.

    def force_encoding new_encoding
      new_encoding = Encoding.find new_encoding unless Encoding === new_encoding
      @encoding = new_encoding
      try_force_encoding @body
      try_force_encoding @raw
      @encoding
    end


    ##
    # Accessor for downcased headers.

    def headers
      return @headers if @headers
      @headers = @_res.to_hash.dup
      @headers.keys.each{|h| @headers[h] = @headers[h].join(", ")}
      @headers
    end

    alias to_hash headers


    ##
    # If there was an error parsing the input as a standard http response,
    # the input is assumed to be a body and HeadlessResponse is used.

    def headless?
      HeadlessResponse === @_res
    end


    ##
    # The version of the HTTP protocol returned.

    def http_version
      @_res.http_version
    end


    ##
    # Ruby inspect.

    def inspect
      content_type = self['Content-Type'] || "text/html"
      "#<#{self.class}:#{@code} #{content_type} #{total_bytes}bytes>"
    end


    ##
    # Check if connection should be closed or not.

    def keep_alive?
      @_res.keep_alive?
    end


    ##
    # Returns the body data parsed according to the content type.
    # If no parser is given will look for the default parser based on
    # the Content-Type, or will return the cached parsed body if available.

    def parsed_body new_parser=nil
      @parsed_body ||= nil

      return @parsed_body if @parsed_body && !new_parser

      new_parser ||= parser

      begin
        new_parser = Kronk.parser_for(new_parser) ||
                     Kronk.find_const(new_parser)
      rescue NameError
        raise InvalidParser, "No such parser: #{new_parser}"
      end if String === new_parser

      raise MissingParser,
        "No parser for Content-Type: #{@_res['Content-Type']}" unless new_parser

      begin
        @parsed_body = new_parser.parse(self.body) or raise RuntimeError

      rescue RuntimeError, ::Exception => e
        msg = ParserError === e ?
                e.message : "#{new_parser} failed parsing body"

        msg << " returned by #{@uri}" if @uri
        raise ParserError, msg
      end
    end


    ##
    # Returns the parsed header hash.

    def parsed_header include_headers=true
      out_headers = headers.dup
      out_headers['status']  = @code
      out_headers['http-version'] = @_res.http_version

      case include_headers
      when nil, false
        nil

      when Array, String
        include_headers = [*include_headers].map{|h| h.to_s.downcase}

        out_headers.keys.each do |key|
          out_headers.delete key unless
            include_headers.include? key.to_s.downcase
        end

        out_headers

      when true
        out_headers
      end
    end


    ##
    # The parser to use on the body.

    def parser
      @parser ||= Kronk.parser_for headers["content-type"]
    end


    ##
    # Assign the parser.

    def parser= parser
      @parser = Kronk.parser_for(parser) || Kronk.find_const(parser)
    rescue NameError
      raise InvalidParser, "No such parser: #{parser}"
    end


    ##
    # Returns the header portion of the raw http response.

    def raw_header include_headers=true
      return if HeadlessResponse === @_res
      headers = "#{@raw.split("\r\n\r\n", 2)[0]}\r\n"

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
    # Returns the location to redirect to. Prepends request url if location
    # header is relative.

    def location
      return @_res['Location'] if !@request || !@request.uri
      @request.uri.merge @_res['Location']
    end


    ##
    # Check if this is a redirect response.

    def redirect?
      @code.to_s =~ /^30\d$/
    end


    ##
    # Follow the redirect and return a new Response instance.
    # Returns nil if not redirect-able.

    def follow_redirect opts={}
      return if !redirect?
      Request.new(self.location, opts).retrieve
    end


    ##
    # Returns the raw response with selective headers and/or the body of
    # the response. Supports the following options:
    # :no_body:: Bool - Don't return the body; default nil
    # :show_headers:: Bool/String/Array - Return headers; default nil

    def selective_string options={}
      str = @body unless options[:no_body]

      if options[:show_headers]
        header = raw_header(options[:show_headers])
        str = [header, str].compact.join "\r\n"
      end

      str
    end


    ##
    # Returns the parsed response with selective headers and/or the body of
    # the response. Supports the following options:
    # :no_body:: Bool - Don't return the body; default nil
    # :show_headers:: Bool/String/Array - Return headers; default nil
    # :parser:: Object - The parser to use for the body; default nil
    # :transform:: Array - Action/path(s) pairs to modify data.
    #
    # Deprecated Options:
    # :ignore_data:: String/Array - Removes the data from given data paths
    # :only_data:: String/Array - Extracts the data from given data paths
    #
    # Example:
    #   response.selective_data :transform => [:delete, ["foo/0", "bar/1"]]
    #   response.selective_data do |trans|
    #     trans.delete "foo/0", "bar/1"
    #   end
    #
    # See Kronk::Path::Transaction for supported transform actions.

    def selective_data options={}
      data = nil

      unless options[:no_body]
        data = parsed_body options[:parser]
      end

      if options[:show_headers]
        header_data = parsed_header(options[:show_headers])
        data &&= [header_data, data]
        data ||= header_data
      end

      Path::Transaction.run data, options do |t|
        # Backward compatibility support
        t.select(*options[:only_data])   if options[:only_data]
        t.delete(*options[:ignore_data]) if options[:ignore_data]

        t.actions.concat options[:transform] if options[:transform]

        yield t if block_given?
      end
    end


    ##
    # Returns a String representation of the response, the response body,
    # or the response headers, parsed or in raw format.
    # Options supported are:
    # :parser:: Object/String - the parser for the body; default nil (raw)
    # :struct:: Boolean - Return data types instead of values
    # :only_data:: String/Array - extracts the data from given data paths
    # :ignore_data:: String/Array - defines which data points to exclude
    # :raw:: Boolean - Force using the unparsed raw response
    # :keep_indicies:: Boolean - indicies of modified arrays display as hashes.
    # :show_headers:: Boolean/String/Array - defines which headers to include
    #
    # If block is given, yields a Kronk::Path::Transaction instance to make
    # transformations on the data. See Kronk::Response#selective_data

    def stringify options={}, &block
      options = options.empty? ? @stringify_opts : merge_stringify_opts(options)

      if !options[:raw] && (options[:parser] || parser || options[:no_body])
        data = selective_data options, &block
        DataString.new data, options
      else
        selective_string options
      end

    rescue MissingParser
      Cmd.verbose "Warning: No parser for #{@_res['Content-Type']} [#{@uri}]"
        selective_string options
    end


    def merge_stringify_opts options # :nodoc:
      options = options.dup
      @stringify_opts.each do |key, val|
        case key
        # Response headers - Boolean, String, or Array
        when :show_headers
          next if options.has_key?(key) &&
                  (options[key].class != Array || val == true || val == false)

          options[key] = (val == true || val == false) ? val :
                                      [*options[key]] | [*val]

        # String or Array
        when :only_data, :ignore_data
          options[key] = [*options[key]] | [*val]

        else
          options[key] = val if options[key].nil?
        end
      end
      options
    end


    ##
    # Check if this is a 2XX response.

    def success?
      @code.to_s =~ /^2\d\d$/
    end


    ##
    # Number of bytes of the response including the header.

    def total_bytes
      self.raw.bytes.count
    end


    ##
    # The URI of the request if or the file read if available.

    def uri
      @request && @request.uri || File === @io && URI.parse(@io.path)
    end


    private


    ##
    # Creates a Net::HTTPResponse instance from an IO instance.

    def response_from_io resp_io
      io = Kronk::BufferedIO === resp_io ?
            resp_io : Kronk::BufferedIO.new(resp_io)

      io.raw_output = @raw

      begin
        resp = Net::HTTPResponse.read_new io
        resp.reading_body io, true do;end

      rescue Net::HTTPBadResponse
        ext = File.extname(resp_io.path)[1..-1] if File === resp_io

        io.read_all
        resp = HeadlessResponse.new @raw, ext

      rescue EOFError
        # If no response was read because it's too short
        unless resp
          io.read_all
          resp = HeadlessResponse.new @raw
        end
      end

      resp
    end


    ##
    # Assigns self.encoding to the passed string if
    # it responds to 'force_encoding'.
    # Returns the string given with the new encoding.

    def try_force_encoding str
      str.force_encoding encoding if str.respond_to? :force_encoding
      str
    end
  end


  ##
  # Mock response object without a header for body-only http responses.

  class HeadlessResponse

    attr_accessor :body, :code

    def initialize body, file_ext=nil
      @body = body
      @raw  = body
      @code = "200"

      encoding = body.respond_to?(:encoding) ? body.encoding : "UTF-8"

      @header = {
        'Content-Type' => "text/#{file_ext || 'html'}; charset=#{encoding}"
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
      head_out = @header.dup
      head_out.keys.each do |key|
        head_out[key.downcase] = [head_out.delete(key)]
      end

      head_out
    end
  end
end
