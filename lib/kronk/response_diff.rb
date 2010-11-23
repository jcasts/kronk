class Kronk

  class ResponseDiff

    ##
    # Make requests, parse the responses return a ResponseDiff object.
    # If the second argument is omitted or is passed :cache, will
    # attempt to compare with the last made request. If there was no last
    # request will compare against nil.
    #
    # Supports the following options:
    # :data:: Hash/String - the data to pass to the http request
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    # :query:: Hash/String - data to append to url query
    # :ignore_data:: String/Array - defines which data points to exclude
    # :ignore_headers:: Bool/String/Array - defines which headers to exclude

    def self.retrieve_new uri1, uri2=:cache, options={}
      resp1 = retrieve uri1, options
      resp2 = retrieve uri2, options

      new resp1, resp2, options
    end


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
      data              = options[:data]
      headers           = options[:headers]
      http_method       = options[:http_method] || :get
      proxy             = options[:proxy]
      follow_redirects  = options[:follow_redirects]

      
    end


    attr_reader :resp1, :resp2

    attr_accessor :ignore_data, :ignore_headers


    def initialize resp1, resp2, options={}
      @resp1 = resp1
      @resp2 = resp2
      @ignore_data    = options[:ignore_data]
      @ignore_headers = options[:ignore_headers]
    end


    ##
    # Returns a diff Array based on the responses' parsed data.

    def data_diff
    end


    ##
    # Returns a diff Array from the raw response Strings.

    def raw_diff
      Differ.diff_by_line raw_response(@resp2), raw_response(@resp1)
    end



    ##
    # Takes a http response instance and returns a raw http response String
    # without the specified headers.

    def raw_response resp, exclude_headers=@ignore_headers
      raw_headers = raw_response_header resp, exclude_headers
      [raw_headers, resp.body].compact.join "\r\n\r\n"
    end


    ##
    # Takes a http response instance and returns the raw header part of the
    # response without the specified headers.

    def raw_response_header resp, exclude_headers=@ignore_headers
      case exclude_headers
      when nil, false
        resp.raw_header

      when Array, String
        ignores = [*exclude_headers]
        resp.raw_header.gsub %r{^(#{ignores.join("|")}).*$}im, ''

      when true
        nil
      end
    end
  end
end
