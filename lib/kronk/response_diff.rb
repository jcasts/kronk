class Kronk

  class ResponseDiff

    class MissingParser < Exception; end

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
    # Response objects must respond to :raw, :raw_header, :header, and :body.

    def initialize resp1, resp2, options={}
      @resp1 = resp1
      @resp2 = resp2
      @ignore_data    = options[:ignore_data]
      @ignore_headers = options[:ignore_headers]
    end


    ##
    # Returns a diff Array based on the responses' parsed data.

    def data_diff exclude_headers=@ignore_headers
      data_response(@resp2, exclude_headers)
      data_response(@resp1, exclude_headers)
    end


    ##
    # Returns a parsed response body as a data object.
    # If a parser is given, it must respond to :parse with a single argument.

    def data_response resp, parser=nil, exclude_headers=@ignore_headers
      parser ||= Kronk.parser_for resp['Content-Type']

      raise MissingParser,
        "No parser for Content-Type: #{resp['Content-Type']}" unless parser

      body_data = parser.parse resp.body
      head_data = data_response_header resp, exclude_headers

      output = {}
      output['body']   = body_data
      output['header'] = head_data if head_data

      output
    end


    ##
    # Takes a http response instance and returns the parsed header part of the
    # response without the specified headers.

    def data_response_header resp, exclude_headers=@ignore_headers
      header = resp.header.to_hash

      case exclude_headers
      when nil, false
        header

      when Array, String
        [*exclude_headers].each do |excluded_header|
          header.delete excluded_header
         end
         header

      when true
        nil
      end
    end


    ##
    # Returns a data string that is diff-able, meaning sorted by
    # Hash keys when available.

    def ordered_data_string data, indent=0
      case data

      when Hash
        output = "{\n"

        key_width = 0
        data.keys.each do |k|
          key_width = k.inspect.length if k.inspect.length > key_width
        end

        data_values =
          data.map do |key, value|
            pad = " " * indent
            subdata = ordered_data_string value, indent + 1
            "#{pad}#{key.inspect.ljust key_width} => #{subdata}"
          end

        output << data_values.sort.join(",\n") << "\n"

        output << "#{" " * indent}}"

      when Array
        output = "[\n"

        data.each do |value|
          pad = " " * indent
          output << "#{pad}#{ordered_data_string value, indent + 1},\n"
        end

        output << "#{" " * indent}]"

      else
        data.inspect
      end
    end


    ##
    # Returns a diff Array from the raw response Strings.

    def raw_diff exclude_headers=@ignore_headers
      Differ.diff_by_line raw_response(@resp2, exclude_headers),
                          raw_response(@resp1, exclude_headers)
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
