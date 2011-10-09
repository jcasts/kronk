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

      start_time = Time.now
      req  = conn.setup_request @http_method,
                :head => header_opts, :body => @body, &block

      req.callback do |resp|
        elapsed_time   = Time.now - start_time
        @response      = Response.new resp.raw_response, nil, self
        @response.time = elapsed_time
        yield @response, nil
      end if block_given?

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
  end
end
