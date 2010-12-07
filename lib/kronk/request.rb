class Kronk

  ##
  # Request wrapper class for net/http.

  class Request

    class NotFoundError < Exception; end

    ##
    # Follows the redirect from a 30X response object and decrease the
    # number of redirects left if it's an Integer.

    def self.follow_redirect resp, options={}
      rdir = options[:follow_redirects]
      rdir = rdir - 1 if Integer === rdir && rdir > 0

      retrieve_uri resp['Location'], options.merge(:follow_redirects => rdir)
    end


    ##
    # Check the rdir value to figure out if redirect should be followed.

    def self.follow_redirect? resp, rdir
      resp.code.to_s =~ /^30\d$/ &&
      (rdir == true || Integer === rdir && rdir > 0)
    end


    ##
    # Returns the value from a url, file, or cache as a String.
    # Options supported are:
    # :data:: Hash/String - the data to pass to the http request
    # :follow_redirects:: Integer/Bool - number of times to follow redirects
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    #
    # TODO: Log request speed.

    def self.retrieve query, options={}
      resp =
        if !local?(query)
          retrieve_uri query, options
        else
          retrieve_file query, options
        end

      begin
        File.open(options[:cache_response], "w+") do |file|
          file.write resp.raw
        end if options[:cache_response]
      rescue => e
        $stderr << "#{e.class}: #{e.message}"
      end

      resp
    rescue SocketError, Errno::ENOENT
      raise NotFoundError, "#{query} could not be found"
    end


    ##
    # Check if a URI should be treated as a local file.

    def self.local? uri
      !(uri =~ %r{^\w+://})
    end


    ##
    # Read http response from a file and return a HTTPResponse instance.

    def self.retrieve_file path, options={}
      Kronk.verbose "\nReading file:\n#{path}\n"

      options = options.dup

      path = Kronk::DEFAULT_CACHE_FILE if path == :cache
      resp = nil

      File.open(path, "r") do |file|
        begin
          resp = Response.read_new file

        rescue Net::HTTPBadResponse
          file.rewind
          resp = HeadlessResponse.new file.read
          resp['Content-Type'] = File.extname path
        end
      end

      resp = follow_redirect resp, options if
        follow_redirect? resp, options[:follow_redirects]

      resp
    end


    ##
    # Make an http request to the given uri and return a HTTPResponse instance.
    # Supports the following options:
    # :data:: Hash/String - the data to pass to the http request
    # :follow_redirects:: Integer/Bool - number of times to follow redirects
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    #
    # Note: if no http method is specified and data is given, will default
    # to using a post request.

    def self.retrieve_uri uri, options={}
      Kronk.verbose "\nRetrieving URL:\n#{uri}\n"

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
    # :data:: Hash/String - the data to pass to the http request
    # :follow_redirects:: Integer/Bool - number of times to follow redirects
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get

    def self.call http_method, uri, options={}
      suffix = options.delete :uri_suffix

      uri    = "#{uri}#{suffix}" if suffix
      uri    = URI.parse uri unless URI === uri

      data   = options[:data]
      data &&= Hash === data ? build_query(data) : data.to_s

      socket = socket_io = nil

      resp = Net::HTTP.start uri.host, uri.port do |http|
        socket = http.instance_variable_get "@socket"
        socket.debug_output = socket_io = StringIO.new

        http.send_request http_method.to_s.upcase,
                          uri.request_uri,
                          data,
                          options[:headers]
      end

      resp.extend Response::Helpers

      r_req, r_resp, r_bytes = Response.read_raw_from socket_io
      resp.instance_variable_set "@raw", r_resp

      resp
    end


    ##
    # Creates a query string from data.

    def self.build_query data, param=nil
      raise ArgumentError,
        "Can't convert #{data.class} to query without a param name" unless
          Hash === data || param

      case data
      when Array
        out = data.map do |value|
          key = "#{param}[]"
          build_query value, key
        end

        out.join "&"

      when Hash
        out = data.sort.map do |key, value|
          key = param.nil? ? key : "#{param}[#{key}]"
          build_query value, key
        end

        out.join "&"

      else
        "#{param}=#{data}"
      end
    end
  end
end
