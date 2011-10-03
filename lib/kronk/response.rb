class Kronk

  ##
  # Mock File IO to allow rewinding on Windows platforms.

  class WinFileIO < StringIO
    attr_accessor :path

    def initialize path, str=""
      @path = path
      super str
    end
  end


  ##
  # Standard Kronk response object.

  class Response

    class MissingParser < Exception; end
    class InvalidParser < Exception; end


    ENCODING_MATCHER = /(^|;\s?)charset=(.*?)\s*(;|$)/

    ##
    # Read http response from a file and return a Kronk::Response instance.

    def self.read_file path
      file     = File.open(path, "rb")
      resp     = new file
      resp.uri = path
      file.close

      resp
    end


    attr_accessor :body, :bytes, :byterate, :code, :headers,
                  :raw, :stringify_opts, :request, :uri

    attr_reader :encoding, :parser, :time

    alias to_hash headers
    alias to_s raw

    ##
    # Create a new Response object from a String or IO.

    def initialize io=nil, res=nil, request=nil
      return unless io
      io = StringIO.new io if String === io

      if io && res
        @_res, debug_io = res, io
      else
        @_res, debug_io = request_from_io(io)
      end

      @headers  = @_res.to_hash.dup
      @headers.keys.each{|h| @headers[h] = @headers[h].join(", ")}

      @encoding = "utf-8" unless @_res["Content-Type"]
      c_type = [*@headers["content-type"]].find{|ct| ct =~ ENCODING_MATCHER}
      @encoding = $2 if c_type
      @encoding ||= "ASCII-8BIT"
      @encoding = Encoding.find(@encoding) if defined?(Encoding)

      raw_req, raw_resp, bytes = read_raw_from debug_io
      @raw      = try_force_encoding raw_resp

      @request  = request ||
                  raw_req = try_force_encoding(raw_req) &&
                  Request.parse(raw_req)

      @time   = 0

      @body   = try_force_encoding(@_res.body) if @_res.body
      @body ||= @raw.split("\r\n\r\n",2)[1]

      @bytes = (@_res['Content-Length'] || @body.bytes.count).to_i

      @code = @_res.code

      @parser = Kronk.parser_for @_res['Content-Type']

      @uri = @request.uri if @request && @request.uri
      @uri = URI.parse io.path if File === io

      @byterate = 0

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
    # Cookie header accessor.

    def cookie
      @_res['Cookie']
    end


    ##
    # Force the encoding of the raw response and body

    def force_encoding new_encoding
      new_encoding = Encoding.find new_encoding unless Encoding === new_encoding
      @encoding = new_encoding
      try_force_encoding @body
      try_force_encoding @raw
      @encoding
    end


    ##
    # If there was an error parsing the input as a standard http response,
    # the input is assumed to be a body and HeadlessResponse is used.

    def headless?
      HeadlessResponse === @_res
    end


    ##
    # Ruby inspect.

    def inspect
      "#<#{self.class}:#{self.code} #{self['Content-Type']} #{total_bytes}bytes>"
    end


    ##
    # Returns the body data parsed according to the content type.
    # If no parser is given will look for the default parser based on
    # the Content-Type, or will return the cached parsed body if available.

    def parsed_body parser=nil
      @parsed_body ||= nil

      return @parsed_body if @parsed_body && !parser

      parser ||= @parser

      begin
        parser = Kronk.parser_for(parser) || Kronk.find_const(parser)
      rescue NameError
        raise InvalidParser, "No such parser: #{parser}"
      end if String === parser

      raise MissingParser,
        "No parser for Content-Type: #{@_res['Content-Type']}" unless parser

      begin
        @parsed_body = parser.parse(self.body) or raise RuntimeError

      rescue RuntimeError, ::Exception => e
        msg = ParserError === e ? e.message : "#{parser} failed parsing body"
        msg << " returned by #{@uri}" if @uri
        raise ParserError, msg
      end
    end


    ##
    # Returns the parsed header hash.

    def parsed_header include_headers=true
      headers = @headers.dup

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
    # Assign the parser.

    def parser= parser
      @parser = Kronk.parser_for(parser) || Kronk.find_const(parser)
    rescue NameError
      raise InvalidParser, "No such parser: #{parser}"
    end


    ##
    # Returns the header portion of the raw http response.

    def raw_header include_headers=true
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

      if !options[:raw] && (options[:parser] || @parser || options[:no_body])
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
    # Assign how long the request took in seconds.

    def time= new_time
      @time = new_time
      @byterate = self.total_bytes / @time.to_f if @raw && @time > 0
      @time
    end


    ##
    # Number of bytes of the response including the header.

    def total_bytes
      self.raw.bytes.count
    end


    private


    ##
    # Creates a Net::HTTPRequest instance from an IO instance.

    def request_from_io resp_io
      # On windows, read the full file and insert contents into
      # a StringIO to avoid failures with IO#read_nonblock
      if Kronk::Cmd.windows? && File === resp_io
        resp_io = WinFileIO.new resp_io.path, io.read
      end

      io = Net::BufferedIO === resp_io ? resp_io : Net::BufferedIO.new(resp_io)
      io.debug_output = debug_io = StringIO.new

      begin
        resp = Net::HTTPResponse.read_new io
        resp.reading_body io, true do;end

      rescue Net::HTTPBadResponse
        ext = "text/html"
        ext = File.extname(resp_io.path) if WinFileIO === resp_io

        resp_io.rewind
        resp = HeadlessResponse.new resp_io.read, ext

      rescue EOFError
        # If no response was read because it's too short
        unless resp
          resp_io.rewind
          resp = HeadlessResponse.new resp_io.read, "html"
        end
      end

      resp.instance_eval do
        @socket ||= true
        @read   ||= true
      end

      [resp, debug_io]
    end


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
    # Assigns self.encoding to the passed string if
    # it responds to 'force_encoding'.
    # Returns the string given with the new encoding.

    def try_force_encoding str
      str.force_encoding @encoding if str.respond_to? :force_encoding
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
        'Content-Type' => ["text/#{file_ext}; charset=#{encoding}"]
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
      @header
    end
  end
end
