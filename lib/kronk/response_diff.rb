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
    # Supports the following options:
    # :parser:: Parser class or instance that responds to :parse
    # :ignore_data:: Ignore specific data points in the body
    # :ignore_headers:: Array of header Strings or Boolean

    def data_diff options={}
      str1 = ordered_data_string data_response(@resp1, options)
      str2 = ordered_data_string data_response(@resp2, options)
      Differ.diff_by_line str2, str1
    end


    ##
    # Returns a parsed response body as a data object.
    # If a parser is given, it must respond to :parse with a single argument.

    def data_response resp, options={}
      parser = options[:parser] || Kronk.parser_for resp['Content-Type']

      options = {:ignore_headers => @ignore_headers,
                 :ignore_data    => @ignore_data}.merge options

      ignore_headers = options[:ignore_headers]
      ignore_data    = options[:ignore_data]

      raise MissingParser,
        "No parser for Content-Type: #{resp['Content-Type']}" unless parser

      head_data = data_response_header resp, ignore_headers

      body_data = parser.parse resp.body
      body_data = exclude_data body_data, ignore_data

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
    # Find specific data points from a nested hash or array data structure.
    # If a block is given, will pass it any matched parent data object path,
    # key, and value.
    #
    # Data points must be an Array or String with a glob-like format.
    # Special characters are: / * = | \ and are interpreted as follows:
    # :key/ - walk down tree by one level from key
    # :*/key - walk down tree from any parent with key as a child
    # :key1|key2 - return elements with key value of key1 or key2
    # :key=val - return elements where key has a value of val
    # :key\* - return root-level element with key "key*"
    #
    # Other examples:
    #   find_data data, root/**=invalid|
    #   # Returns an Array of grand-children key/value pairs
    #   # where the value is 'invalid' or blank

    def find_data data, data_paths, &block
      [*data_paths].each do |data_path|

        while data_path do
          key, value, recursive, data_path = parse_data_path data_path
          yield_data_points data, key, value, recursive, &block
        end
      end
    end


    ##
    # Parses a given data point and returns an array with the following:
    # - Key to match
    # - Value to match
    # - Recursive matching
    # - New data path value

    def parse_data_path data_path
      data_path  = data_path.dup
      key        = nil
      value      = nil
      recursive  = false

      until key && key != "**" || value || data_path.empty? do
        value = data_path.slice!(%r{((.*?[^\\])+?/)})
        (value ||= data_path).sub! /\/$/, ''
        data_path = nil if value == data_path

        key   = value.slice! %r{((.*?[^\\])+?=)}
        key, value = value, nil if key.nil?
        key.sub! /\=$/, ''

        value = parse_path_item value if value

        if key =~ /^\*{2,}$/
          key = /.*/
          recursive = true
        else
          parse_path_item key
        end
      end

      [key, value, recursive, data_path]
    end


    ##
    # Decide whether to make path item a regex or not.

    def parse_path_item str
      if str =~ /(^|[^\\])(\*|\?|\|)/
        str.gsub!(/(^|[^\\])(\*|\?)/, '\1.\2')
        str = /#{str}/
      else
        str.gsub! "\\", ""
      end

      str
    end


    ##
    # Yield data object and key, if a specific key or value matches
    # the given data.

    def yield_data_points data, mkey, mvalue=nil, recursive=false, &block
      return unless Hash === data || Array === data

      each_data_item data do |key, value|
        found = match_data_item(mkey, key) &&
                match_data_item(mvalue, value)

        yield data, key if found
        yield_data_points data[key], mkey, mvalue, true, &block if recursive
      end
    end


    ##
    # Check if data key or value is a match for nested data searches.

    def match_data_item item1, item2
      if Regexp === item1
        item2.to_s =~ item1
      elsif item1.nil?
        true
      else
        item2.to_s == item1.to_s
      end
    end


    ##
    # Universal iterator for Hash and Array objects.

    def each_data_item data, &block
      if Hash === data
        data.each &block
      elsif Array === data
        data.each_with_index do |val, i|
          block.call i, val
        end
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
