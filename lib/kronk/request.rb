class Kronk

  ##
  # Performs HTTP requests and returns a Kronk::Response instance.

  class Request

    # Raised by Request.parse when parsing invalid http request string.
    class ParseError < Kronk::Error; end

    # Matches the first line of an http request string or a fully
    # qualified URL.
    REQUEST_LINE_MATCHER =
 %r{(?:^|[\s'"])(?:([a-z]+)\s)?(?:(https?://[^/]+)(/[^\s'";]*)?|(/[^\s'";]*))}i


    ##
    # Creates a query string from data.

    def self.build_query data, param=nil
      return data.to_s unless param || Hash === data

      case data
      when Array
        out = data.map do |value|
          key = "#{param}[]"
          build_query value, key
        end

        out.join "&"

      when Hash
        out = data.map do |key, value|
          key = param.nil? ? key : "#{param}[#{key}]"
          build_query value, key
        end

        out.join "&"

      else
        "#{param}=#{data}"
      end
    end


    ##
    # Build the URI to use for the request from the given uri or
    # path and options.

    def self.build_uri uri, opts={}
      uri ||= opts[:host]

      uri = "#{uri}#{opts[:path]}#{opts[:uri_suffix]}"
      uri = "http://#{uri}" unless uri.to_s =~ %r{^(\w+://|/)}

      uri = URI.parse uri unless URI === uri

      unless uri.host
        host = Kronk.config[:default_host]
        host = "http://#{host}" unless host.to_s =~ %r{^\w+://}
        uri  = URI.parse(host) + uri
      end

      if opts[:query]
        query = build_query opts[:query]
        uri.query = [uri.query, query].compact.join "&"
      end

      uri.path = "/" if uri.path.empty?

      uri
    end


    ##
    # Parses a raw HTTP request-like string into a Kronk::Request instance.
    # Options passed are used as default values for Request#new.

    def self.parse str, opts={}
      opts = parse_to_hash str, opts
      raise ParseError unless opts

      new opts.delete(:host), opts
    end


    ##
    # Parses a raw HTTP request-like string into a Kronk::Request options hash.
    # Also parses most single access log entries. Options passed are used
    # as default values for Request#new.

    def self.parse_to_hash str, opts={}
      lines = str.split("\n")
      return if lines.empty?

      body_start = nil

      opts[:headers] ||= {}

      lines.shift.strip =~ REQUEST_LINE_MATCHER
      opts.merge! :http_method => $1,
                  :host        => $2,
                  :path        => ($3 || $4)

      lines.each_with_index do |line, i|
        case line
        when /^Host: /
          opts[:host] = line.split(": ", 2)[1].strip

        when "", "\r"
          body_start = i+1
          break

        else
          name, value = line.split(": ", 2)
          opts[:headers][name] = value.strip if value
        end
      end

      opts[:data] = lines[body_start..-1].join("\n") if body_start

      opts.delete(:host)        if !opts[:host]
      opts.delete(:path)        if !opts[:path]
      opts.delete(:headers)     if opts[:headers].empty?
      opts.delete(:http_method) if !opts[:http_method]
      opts.delete(:data)        if opts[:data] && opts[:data].strip.empty?

      return if opts.empty?
      opts
    end


    ##
    # Parses a nested query. Stolen from Rack.

    def self.parse_nested_query qs, d=nil
      params = {}
      d ||= "&;"

      (qs || '').split(%r{[#{d}] *}n).each do |p|
        k, v = CGI.unescape(p).split('=', 2)
        normalize_params(params, k, v)
      end

      params
    end


    ##
    # Stolen from Rack.

    def self.normalize_params params, name, v=nil
      name =~ %r(\A[\[\]]*([^\[\]]+)\]*)
      k = $1 || ''
      after = $' || ''

      return if k.empty?

      if after == ""
        params[k] = v

      elsif after == "[]"
        params[k] ||= []
        raise TypeError,
          "expected Array (got #{params[k].class.name}) for param `#{k}'" unless
            params[k].is_a?(Array)

        params[k] << v

      elsif after =~ %r(^\[\]\[([^\[\]]+)\]$) || after =~ %r(^\[\](.+)$)
        child_key = $1
        params[k] ||= []
        raise TypeError,
          "expected Array (got #{params[k].class.name}) for param `#{k}'" unless
            params[k].is_a?(Array)

        if params[k].last.is_a?(Hash) && !params[k].last.key?(child_key)
          normalize_params(params[k].last, child_key, v)
        else
          params[k] << normalize_params({}, child_key, v)
        end

      else
        params[k] ||= {}
        raise TypeError,
          "expected Hash (got #{params[k].class.name}) for param `#{k}'" unless
            params[k].is_a?(Hash)

        params[k] = normalize_params(params[k], after, v)
      end

      return params
    end


    class << self
      %w{get post put delete trace head options}.each do |name|
        class_eval <<-"END"
          def #{name} uri, opts={}, &block
            opts[:http_method] = "#{name}"
            new(uri, opts).retrieve(&block)
          end
        END
      end
    end


    attr_accessor :headers, :proxy, :response, :timeout

    attr_reader :body, :http_method, :uri, :use_cookies

    ##
    # Build an http request to the given uri and return a Response instance.
    # Supports the following options:
    # :data:: Hash/String - the data to pass to the http request body
    # :file:: String - the path to a file to upload; overrides :data
    # :form:: Hash/String - similar to :data but sets content-type header
    # :query:: Hash/String - the data to append to the http request path
    # :user_agent:: String - user agent string or alias; defaults to 'kronk'
    # :auth:: Hash - must contain :username and :password; defaults to nil
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    # :proxy:: Hash/String - http proxy to use; defaults to {}
    # :accept_encoding:: Array/String - list of encodings the server can return
    #
    # Note: if no http method is specified and data is given, will default
    # to using a post request.

    def initialize uri, opts={}
      @auth = opts[:auth]

      @connection = nil
      @response   = nil
      @body       = nil
      @_req       = nil

      @headers = opts[:headers] || {}

      @headers["Accept-Encoding"] = [
        @headers["Accept-Encoding"].to_s.split(","),
        Array(opts[:accept_encoding])
      ].flatten.compact.uniq.join(",")
      @headers.delete "Accept-Encoding" if @headers["Accept-Encoding"].empty?

      @headers['Connection'] ||= 'Keep-Alive'

      @timeout = opts[:timeout] || Kronk.config[:timeout]

      @uri = self.class.build_uri uri, opts

      @proxy = {}

      if opts[:proxy] && !opts[:proxy].empty?
        @proxy = opts[:proxy]
        @proxy = {:host => @proxy.to_s} unless Hash === @proxy
        @proxy[:host], port = @proxy[:host].split ":"
        @proxy[:port] ||= port || 8080
      end

      if opts[:file]
        self.body = File.open(opts[:file], 'rb')
      elsif opts[:form]
        self.form_data = opts[:form]
      elsif opts[:data]
        self.body = opts[:data]
      end

      self.user_agent ||= opts[:user_agent]

      self.http_method = opts[:http_method] || (@body ? "POST" : "GET")

      self.use_cookies = opts.has_key?(:no_cookies) ?
                          !opts[:no_cookies] : Kronk.config[:use_cookies]
    end


    ##
    # Returns the basic auth credentials if available.

    def auth
      @auth ||= Hash.new

      if !@auth[:username] && @headers['Authorization']
        require 'base64'
        str = Base64.decode64 @headers['Authorization'].split[1]
        username, password = str.split(":", 2)
        @auth = {:username => username, :password => password}.merge @auth
      end

      @auth
    end


    ##
    # Assign request body. Supports String, Hash, and IO.

    def body= data
      case data
      when Hash
        self.form_data = data

      when String
        dont_chunk!
        @body = data

      else
        if data.respond_to?(:read)
          ext   = File.extname(data.path.to_s)[1..-1] if data.respond_to?(:path)
          ext ||= "binary"

          @headers['Content-Type'] = "application/#{ext}"

          @body = data
        else
          dont_chunk!
          @body = data.to_s
        end
      end

      @headers['Content-Length'] = @body.size.to_s if @body.respond_to?(:size)
      @headers['Transfer-Encoding'] = 'chunked' if !@headers['Content-Length']

      @body
    end


    ##
    # Reference to the HTTP connection instance.

    def connection
      return @connection if @connection

      @connection = Kronk::HTTP.new @uri.host, @uri.port,
                      :proxy => @proxy,
                      :ssl   => !!(@uri.scheme =~ /^https$/)

      @connection.open_timeout = @connection.read_timeout = @timeout if @timeout

      @connection
    end


    ##
    # Assigns the cookie string.

    def cookie= cookie_str
      @headers['Cookie'] = cookie_str if @use_cookies
    end


    ##
    # Assigns body of the request with form headers.

    def form_data= data
      dont_chunk!
      @headers['Content-Type'] = "application/x-www-form-urlencoded"
      @body = self.class.build_query data
    end


    ##
    # Assigns the http method.

    def http_method= new_verb
      @http_method = new_verb.to_s.upcase
    end


    ##
    # Decide whether to use cookies or not.

    def use_cookies= bool
      if bool && (!@headers['Cookie'] || @headers['Cookie'].empty?)
        cookie = Kronk.cookie_jar.get_cookie_header @uri.to_s
        @headers['Cookie'] = cookie unless cookie.empty?

      elsif !bool
        @headers.delete 'Cookie'
      end

      @use_cookies = bool
    end


    ##
    # Assign a User Agent header.

    def user_agent= new_ua
      @headers['User-Agent'] =
        new_ua && Kronk.config[:user_agents][new_ua.to_s] ||
        new_ua || Kronk::DEFAULT_USER_AGENT
    end


    ##
    # Read the User Agent header.

    def user_agent
      @headers['User-Agent']
    end


    ##
    # Check if this is an SSL request.

    def ssl?
      @uri.scheme == "https"
    end


    ##
    # Assign whether to use ssl or not.

    def ssl= bool
      @uri.scheme = bool ? "https" : "http"
    end


    ##
    # Retrieve this requests' response. Returns a Kronk::Response once the
    # full HTTP response has been read. If a block is given, will yield
    # the response and body chunks as they get received.
    #
    # Note: Block will yield the full body if the response is compressed
    # using Deflate as the Deflate format does not support streaming.
    #
    # Options are passed directly to the Kronk::Response constructor.

    def retrieve opts={}, &block
      start_time = Time.now

      @response = stream opts

      @response.body(&block) # make sure to read the full body from io
      @response.time = Time.now - start_time - @response.conn_time

      @response
    end


    ##
    # Retrieve this requests' response but only reads HTTP headers before
    # returning and leaves the connection open.
    #
    # Options are passed directly to the Kronk::Response constructor.
    #
    # Connection must be closed using:
    #   request.connection.finish

    def stream opts={}
      retried = false

      begin
        start_time = Time.now
        connection.start unless connection.started?
        conn_time  = Time.now - start_time

        @response = connection.request http_request, @body, opts
        @response.conn_time = conn_time
        @response.request   = self

        @response

      rescue EOFError
        raise if retried
        @connection = nil
        retried = true
        retry
      end
    end


    ##
    # Returns this Request instance as an options hash.

    def to_hash
      hash = {
        :host        => "#{@uri.scheme}://#{@uri.host}:#{@uri.port}",
        :path        => @uri.request_uri,
        :user_agent  => self.user_agent,
        :timeout     => @timeout,
        :http_method => self.http_method,
        :no_cookies  => !self.use_cookies
      }

      hash[:auth]    = @auth if @auth
      hash[:data]    = @body if @body
      hash[:headers] = @headers unless @headers.empty?
      hash[:proxy]   = @proxy   unless @proxy.empty?

      hash
    end


    ##
    # Returns the raw HTTP request String.

    def to_s
      out = "#{@http_method} #{@uri.request_uri} HTTP/1.1\r\n"
      out << "host: #{@uri.host}:#{@uri.port}\r\n"

      http_request.each do |name, value|
        out << "#{name}: #{value}\r\n" unless name =~ /host/i
      end

      out << "\r\n"
      out << @body.to_s
    end


    ##
    # Ruby inspect.

    def inspect
      "#<#{self.class}:#{self.http_method} #{self.uri}>"
    end


    ##
    # Returns the Net::HTTPRequest subclass instance.

    def http_request
      req = VanillaRequest.new @http_method, @uri.request_uri, @headers

      req.basic_auth @auth[:username], @auth[:password] if
        @auth && @auth[:username]

      @body.respond_to?(:read) ? req.body_stream = @body : req.body = @body

      req
    end


    private


    def dont_chunk!
      @headers.delete('Transfer-Encoding') if
        @headers['Transfer-Encoding'].to_s.downcase == 'chunked'
    end


    ##
    # Allow any http method to be sent

    class VanillaRequest
      def self.new method, path, initheader=nil
        klass = Class.new Net::HTTPRequest
        klass.const_set "METHOD", method.to_s.upcase
        klass.const_set "REQUEST_HAS_BODY", true
        klass.const_set "RESPONSE_HAS_BODY", true

        klass.new path, initheader
      end
    end
  end
end

unless File.instance_methods.include? :size
  class File
    def size
      FileTest.size self.path
    end
  end
end
