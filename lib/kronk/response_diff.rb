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
    # Read http response from a file and return a HTTP::Message instance.

    def self.retrieve_file path
      path = DEFAULT_CACHE_FILE if path == :cache
      Response.read_new File.open(path, "r")
    end


    ##
    # Make an http request to the given uri and return a HTTP::Message instance.
    # Supports the following options:
    # :data:: Hash/String - the data to pass to the http request
    # :follow_redirects:: Integer/Bool - number of times to follow redirects
    # :headers:: Hash - extra headers to pass to the request
    # :http_method:: Symbol - the http method to use; defaults to :get
    # :proxy:: String - the proxy host and port
    # :query:: Hash/String - data to append to url query

    def self.retrieve_uri uri, options={}
      data              = options[:data]
      headers           = options[:headers]
      http_method       = options[:http_method] || :get
      query             = options[:query]
      proxy             = options[:proxy]
      follow_redirects  = options[:follow_redirects]

      
    end


    ##
    # Workaround for bug in httpclient.

    def self.fix_response resp
      http_version = resp.header.http_version
      return resp unless http_version && http_version =~ /^\d+(\.\d+)*$/

      resp.header.http_version = resp.header.http_version.to_f
      resp
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
    end



    ##
    # Takes a HTTP::Message instance and returns a raw http response String
    # without the specified headers.

    def raw_response resp, exclude_headers=@ignore_headers
      case exclude_headers

      when nil, false
        resp.dump

      when true
        resp.body

      when Array, String
        ignores = [*excluded_headers]
        resp.header.all.delete_if{|h| ignores.include? h[0] }
        resp.dump
      end
    end


    def raw_response_header resp, exclude_headers=@ignore_headers
      case exclude_headers
      when nil, false

      when Array, String
        ignores = [*excluded_headers]

      when true
        nil
      end
    end
  end
end
