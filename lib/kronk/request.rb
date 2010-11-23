class Kronk

  class Request

    ##
    # Returns the value from a url, file, or cache as a String.
    # Options supported are:
    # :data:: Hash/String - the data to pass to the http request
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    # :query:: Hash/String - data to append to url query
    #
    # TODO: Log request speed.

    def self.retrieve query, options={}
      if query =~ %r{^\w+://}
        retrieve_uri query, options
      else
        retrieve_file query
      end
    end


    ##
    # Read http response from a file and return a HTTPResponse instance.

    def self.retrieve_file path
      path = DEFAULT_CACHE_FILE if path == :cache
      Response.read_new File.open(path, "r")
    end


    ##
    # Make an http request to the given uri and return a HTTPResponse instance.
    # Supports the following options:
    # :data:: Hash/String - the data to pass to the http request
    # :follow_redirects:: Integer/Bool - number of times to follow redirects
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    # :proxy:: String - the proxy host and port

    def self.retrieve_uri uri, options={}
      options     = options.dup
      http_method = options.delete(:http_method) || :get

      self.call http_method, uri, options
    end


    ##
    # Make an http request to the given uri and return a HTTPResponse instance.
    # Supports the following options:
    # :data:: Hash/String - the data to pass to the http request
    # :follow_redirects:: Integer/Bool - number of times to follow redirects
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    # :proxy:: String - the proxy host and port

    def self.call http_method, uri, options={}
      uri  = URI.parse uri unless URI === uri

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
        out = data.map do |key, value|
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
