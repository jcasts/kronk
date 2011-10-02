class Kronk
  class Request

    ##
    # Retrieve this requests' response asynchronously with em-http-request.
    #
    #   req  = Request.new "example.com"
    #   em_req = req.retrieve_async do |kronk_response|
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
        yield @response
      end if block_given?

      req.errback do |c|
        next if c.error
        c.instance_variable_set :@error,
          Kronk::NotFoundError.new("#{@uri} could not be found")
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
