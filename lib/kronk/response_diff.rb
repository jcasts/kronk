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
      resp1 = Request.retrieve uri1, options
      resp2 = Request.retrieve uri2, options

      new resp1, resp2, options
    end


    attr_reader :resp1, :resp2

    attr_accessor :ignore_data, :ignore_headers


    ##
    # Create a ResponseDiff object based on two http responses.
    # Response objects must respond to :raw, :raw_header, and :body.

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
    # Returns a parsed response body as a data object.
    # If a parser is given, it must respond to :parse with a single argument.

    def parse_data resp, parser=nil
      parser ||=
        Kronk.config[:content_types].select do |key, value|
          (resp['Content-Type'] =~ key) && value
        end

      parser = Kernel.const_get value if String === parser

      raise MissingParser,
        "No parser for Content-Type: #{resp['Content-Type']}" unless parser

      parser.parse resp.body
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
