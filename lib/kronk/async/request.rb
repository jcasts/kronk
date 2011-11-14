class Kronk
  class Request

    class EMError < Kronk::Exception; end

    ##
    # Retrieve this requests' response asynchronously with em-http-request.
    # Returns a EM::HttpConnection instance.
    #
    # Passing a block will yield a Kronk::Response instance and/or
    # an Exception instance if an error was caught.
    #
    #   req  = Request.new "example.com"
    #   em_req = req.retrieve_async do |kronk_response, err|
    #     # do something with Kronk::Response instance here
    #   end
    #
    #   em_req.callback { ... }
    #   em_req.error    { ... }

    def retrieve_async &block
      header_opts = @headers.dup

      if @auth && !@auth.empty?
        header_opts['Authorization'] ||= []
        header_opts['Authorization'][0] = @auth[:username] if @auth[:username]
        header_opts['Authorization'][1] = @auth[:password] if @auth[:password]
      end

      conn = async_http

      sock_rd, sock_wr = IO.pipe

      start_time = Time.now
      req  = conn.setup_request @http_method,
                :head => header_opts, :body => @body, &block

      return req unless block_given?

      @response = nil

      req.headers do |resp_headers|
        async_raw_headers sock_wr, resp_headers
      end

      req.stream do |chunk|
        sock_wr << chunk
      end

      req.callback do |resp|
        elapsed_time   = Time.now - start_time
        sock_wr.close
        @response      = Response.new sock_rd, :request => self
        @response.time = elapsed_time
        yield @response, nil
      end

      req.errback do |c|
        err = c.error ?
              EMError.new(c.error) :
              Kronk::NotFoundError.new("#{@uri} could not be found")

        yield nil, err
      end

      req
    end


    ##
    # Return an EM::HttpRequest instance.

    def async_http
      unless @proxy.empty?
        proxy_opts = @proxy.dup
        proxy_opts[:authorization] = [
          proxy_opts.delete(:username),
          proxy_opts.delete(:password)
        ] if proxy_opts[:username] || proxy_opts[:password]
      end

      EventMachine::HttpRequest.new @uri,
        :connect_timeout    => @timeout,
        :inactivity_timeout => @timeout,
        :proxy              => proxy_opts
    end


    private

    def async_raw_headers device, rheader
      device << "HTTP/#{rheader.http_version} "
      device << "#{rheader.status} #{rheader.http_reason}\r\n"

      rheader.each do |key, val|
        device << "#{key}: #{val}\r\n"
      end

      device << "\r\n"
    end
  end
end
