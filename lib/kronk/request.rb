class Kronk

  ##
  # Request wrapper class for net/http.

  class Request

    # Generic Request exception.
    class Exception < ::Exception; end

    # Raised when the URI was not resolvable.
    class NotFoundError < Exception; end

    # Raised when HTTP times out.
    class TimeoutError < Exception; end

    ##
    # Follows the redirect from a 30X response object and decrease the
    # number of redirects left if it's an Integer.

    def self.follow_redirect resp, options={}
      Kronk::Cmd.verbose "Following redirect..."

      rdir = options[:follow_redirects]
      rdir = rdir - 1 if Integer === rdir && rdir > 0

      options = options.merge :follow_redirects => rdir,
                              :http_method      => :get

      retrieve_uri resp['Location'], options
    end


    ##
    # Check the rdir value to figure out if redirect should be followed.

    def self.follow_redirect? resp, rdir
      resp.code.to_s =~ /^30\d$/ &&
      (rdir == true || Integer === rdir && rdir > 0)
    end


    ##
    # Returns the value from a url, file, or IO as a String.
    # Options supported are:
    # :data:: Hash/String - the data to pass to the http request
    # :query:: Hash/String - the data to append to the http request path
    # :follow_redirects:: Integer/Bool - number of times to follow redirects
    # :user_agent:: String - user agent string or alias; defaults to 'kronk'
    # :auth:: Hash - must contain :username and :password; defaults to nil
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    # :proxy:: Hash/String - http proxy to use; defaults to nil

    def self.retrieve uri, options={}
      if IO === uri || StringIO === uri
        resp = retrieve_io uri, options
      elsif File.file? uri.to_s
        resp = retrieve_file uri, options
      else
        resp = retrieve_uri uri, options
        Kronk.history << uri
      end

      begin
        File.open(options[:cache_response], "wb+") do |file|
          file.write resp.raw
        end if options[:cache_response]
      rescue => e
        $stderr << "#{e.class}: #{e.message}"
      end

      resp

    rescue SocketError, Errno::ENOENT, Errno::ECONNREFUSED
      raise NotFoundError, "#{uri} could not be found"

    rescue Timeout::Error
      raise TimeoutError, "#{uri} took too long to respond"
    end


    ##
    # Read http response from a file and return a HTTPResponse instance.

    def self.retrieve_file path, options={}
      Kronk::Cmd.verbose "Reading file:  #{path}\n"

      options = options.dup
      resp    = nil

      File.open(path, "rb") do |file|

        # On windows, read the full file and insert contents into
        # a StringIO to avoid failures with IO#read_nonblock
        file = StringIO.new file.read if Kronk::Cmd.windows?

        begin
          resp = Response.read_new file

        rescue Net::HTTPBadResponse
          file.rewind
          resp = HeadlessResponse.new file.read, File.extname(path)
        end
      end

      resp = follow_redirect resp, options if
        follow_redirect? resp, options[:follow_redirects]

      resp
    end


    ##
    # Read the http response from an IO instance and return a HTTPResponse.

    def self.retrieve_io io, options={}
      Kronk::Cmd.verbose "Reading IO..."

      options = options.dup

      resp = nil

      begin
        resp = Response.read_new io

      rescue Net::HTTPBadResponse
        io.rewind
        resp = HeadlessResponse.new io.read
      end

      resp = follow_redirect resp, options if
        follow_redirect? resp, options[:follow_redirects]

      resp
    end


    ##
    # Make an http request to the given uri and return a HTTPResponse instance.
    # Supports the following options:
    # :data:: Hash/String - the data to pass to the http request
    # :query:: Hash/String - the data to append to the http request path
    # :follow_redirects:: Integer/Bool - number of times to follow redirects
    # :user_agent:: String - user agent string or alias; defaults to 'kronk'
    # :auth:: Hash - must contain :username and :password; defaults to nil
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    # :proxy:: Hash/String - http proxy to use; defaults to nil
    #
    # Note: if no http method is specified and data is given, will default
    # to using a post request.

    def self.retrieve_uri uri, options={}
      options     = options.dup
      http_method = options.delete(:http_method)
      http_method ||= options[:data] ? :post : :get

      resp = self.call http_method, uri, options

      resp = follow_redirect resp, options if
        follow_redirect? resp, options[:follow_redirects]

      resp
    end


    ##
    # Make an http request to the given uri and return a HTTPResponse instance.
    # Supports the following options:
    # :data:: Hash/String - the data to pass to the http request body
    # :query:: Hash/String - the data to append to the http request path
    # :user_agent:: String - user agent string or alias; defaults to 'kronk'
    # :auth:: Hash - must contain :username and :password; defaults to nil
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    # :proxy:: Hash/String - http proxy to use; defaults to nil

    def self.call http_method, uri, options={}
      uri = build_uri uri, options

      data   = options[:data]
      data &&= build_query data

      options[:headers] ||= Hash.new
      options[:headers]['User-Agent'] ||= get_user_agent options[:user_agent]

      unless options[:headers]['Cookie'] || !use_cookies?(options)
        cookie = Kronk.cookie_jar.get_cookie_header uri.to_s
        options[:headers]['Cookie'] = cookie unless cookie.empty?
      end

      socket = socket_io = nil

      proxy_addr, proxy_opts =
        if Hash === options[:proxy]
          [options[:proxy][:address], options[:proxy]]
        else
          [options[:proxy], {}]
        end

      http_class = proxy proxy_addr, proxy_opts

      req = http_class.new uri.host, uri.port
      req.use_ssl = true if uri.scheme =~ /^https$/

      options[:timeout] ||= Kronk.config[:timeout]
      req.read_timeout = options[:timeout] if options[:timeout]

      elapsed_time = nil

      resp = req.start do |http|
        socket = http.instance_variable_get "@socket"
        socket.debug_output = socket_io = StringIO.new

        req = VanillaRequest.new http_method.to_s.upcase,
                uri.request_uri, options[:headers]

        if options[:auth] && options[:auth][:username]
          req.basic_auth options[:auth][:username],
                         options[:auth][:password]
        end

        Kronk::Cmd.verbose "Retrieving URL:  #{uri}\n"

        start_time = Time.now
        http.request req, data

        elapsed_time = Time.now - start_time
      end

      Kronk.cookie_jar.set_cookies_from_headers uri.to_s, resp.to_hash if
        use_cookies? options

      resp.extend Response::Helpers
      resp.set_helper_attribs socket_io
      resp.request_time = elapsed_time.to_f
      resp.request_uri  = uri.to_s

      resp
    end


    ##
    # Build the URI to use for the request from the given uri or
    # path and options.

    def self.build_uri uri, options={}
      suffix = options[:uri_suffix]

      uri = "http://#{uri}"   unless uri.to_s =~ %r{^(\w+://|/)}
      uri = "#{uri}#{suffix}" if suffix
      uri = URI.parse uri unless URI === uri
      uri = URI.parse(Kronk.config[:default_host]) + uri unless uri.host

      if options[:query]
        query = build_query options[:query]
        uri.query = [uri.query, query].compact.join "&"
      end

      uri
    end


    ##
    # Checks if cookies should be used and set.

    def self.use_cookies? options
      return !options[:no_cookies] if options.has_key? :no_cookies
      Kronk.config[:use_cookies]
    end


    ##
    # Gets the user agent to use for the request.

    def self.get_user_agent agent
      agent && Kronk.config[:user_agents][agent.to_s] || agent ||
        Kronk.config[:user_agents]['kronk']
    end


    ##
    # Return proxy http class.
    # The proxy_opts arg can be a uri String or a Hash with the :address key
    # and optional :username and :password keys.

    def self.proxy addr, proxy_opts={}
      return Net::HTTP unless addr

      host, port = addr.split ":"
      port ||= proxy_opts[:port] || 8080

      user = proxy_opts[:username]
      pass = proxy_opts[:password]

      Kronk::Cmd.verbose "Using proxy #{addr}\n" if host

      Net::HTTP::Proxy host, port, user, pass
    end


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
