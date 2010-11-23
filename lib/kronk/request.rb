class Kronk

  class Request

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

      resp.extend Kronk::Response::Helpers

      r_req, r_resp, r_bytes = Kronk::Response.read_raw_from socket_io
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
