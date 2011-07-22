class Kronk

  ##
  # Wraps an http response.

  class Response

    class MissingParser < Exception; end

    ENCODING_MATCHER = /(^|;\s?)charset=(.*?)\s*(;|$)/

    ##
    # Read http response from a file and return a HTTPResponse instance.

    def self.read_file path
      Kronk::Cmd.verbose "Reading file:  #{path}\n"

      file     = File.open(path, "rb")
      resp     = new file
      resp.uri = path
      file.close

      resp
    end


    attr_accessor :body, :bytes, :code, :headers, :parser,
                  :raw, :request, :time, :uri

    ##
    # Returns the encoding provided in the Content-Type header or
    # "binary" if charset is unavailable.
    # Returns "utf-8" if no content type header is missing.
    attr_reader :encoding

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

      @headers  = @_res.to_hash

      @encoding = "utf-8" unless @_res["Content-Type"]
      c_type = @headers["content-type"].find{|ct| ct =~ ENCODING_MATCHER}
      @encoding = $2 if c_type
      @encoding ||= "binary"
      @encoding = Encoding.find(@encoding) if defined?(Encoding)

      raw_req, raw_resp, bytes = read_raw_from debug_io
      @bytes    = bytes.to_i
      @raw      = try_force_encoding raw_resp

      @request  = request ||
                  raw_req = try_force_encoding(raw_req) &&
                  Request.parse(raw_req)

      @time     = 0

      @body     = try_force_encoding(@_res.body) if @_res.body
      @body   ||= @raw.split("\r\n\r\n",2)[1]

      @code = @_res.code

      @parser = Kronk.parser_for @_res['Content-Type']

      @uri = @request.uri if @request && @request.uri
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
    # Returns the body data parsed according to the content type.
    # If no parser is given will look for the default parser based on
    # the Content-Type, or will return the cached parsed body if available.

    def parsed_body parser=nil
      @parsed_body ||= nil

      return @parsed_body if @parsed_body && !parser

      if String === parser
        parser = Kronk.parser_for(parser) || Kronk.find_const(parser)
      end

      parser ||= @parser

      raise MissingParser,
        "No parser for Content-Type: #{@_res['Content-Type']}" unless parser

      @parsed_body = parser.parse self.body
    end


    ##
    # Returns the parsed header hash.

    def parsed_header include_headers=true
      headers = @_res.to_hash.dup

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
    # Check if this is a redirect response.

    def redirect?
      @code.to_s =~ /^30\d$/
    end


    ##
    # Follow the redirect and return a new Response instance.
    # Returns nil if not redirect-able.

    def follow_redirect opts={}
      return if !redirect?
      Request.new(@_res['Location'], opts).retrieve
    end


    ##
    # Returns the raw response with selective headers and/or the body of
    # the response. Supports the following options:
    # :no_body:: Bool - Don't return the body; default nil
    # :with_headers:: Bool/String/Array - Return headers; default nil

    def selective_string options={}
      str = @body unless options[:no_body]

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


    ##
    # Returns a String representation of the response, the response body,
    # or the response headers, parsed or in raw format.
    # Options supported are:
    # :parser:: Object/String - the parser for the body; default nil (raw)
    # :struct:: Boolean - Return data types instead of values
    # :only_data:: String/Array - extracts the data from given data paths
    # :ignore_data:: String/Array - defines which data points to exclude
    # :raw:: Boolean - Force using the unparsed raw response
    # :keep_indicies:: Boolean - keep the original indicies of modified arrays,
    #   and return them as hashes.
    # :with_headers:: Boolean/String/Array - defines which headers to include

    def stringify options={}
      if !options[:raw] && (options[:parser] || @parser)
        data = selective_data options
        Diff.ordered_data_string data, options[:struct]
      else
        selective_string options
      end

    rescue MissingParser
      Cmd.verbose "Warning: No parser for #{@_res['Content-Type']} [#{@uri}]"
        selective_string options
    end


    ##
    # Check if this is a 2XX response.

    def success?
      @code.to_s =~ /^2\d\d$/
    end


    private


    ##
    # Creates a Net::HTTPRequest instance from an IO instance.

    def request_from_io resp_io
      # On windows, read the full file and insert contents into
      # a StringIO to avoid failures with IO#read_nonblock
      if Kronk::Cmd.windows? && File === resp_io
        path = resp_io.path
        resp_io = StringIO.new io.read
        resp_io.instance_eval "def path; '#{path}'; end"
      end

      io = Net::BufferedIO === resp_io ? resp_io : Net::BufferedIO.new(resp_io)
      io.debug_output = debug_io = StringIO.new

      begin
        resp = Net::HTTPResponse.read_new io
        resp.reading_body io, true do;end

      rescue Net::HTTPBadResponse
        raise unless resp_io.respond_to? :path

        resp_io.rewind
        resp = HeadlessResponse.new resp_io.read, File.extname(resp_io.path)

      rescue EOFError
      end

      socket = resp.instance_variable_get "@socket"
      read   = resp.instance_variable_get "@read"

      resp.instance_variable_set "@socket", true unless socket
      resp.instance_variable_set "@read",   true

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
      @header
    end
  end
end
