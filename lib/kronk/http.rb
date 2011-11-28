class Kronk

  class HTTPBadResponse < Net::HTTPBadResponse; end

  ##
  # Wrapper for Net::HTTP

  class HTTP < Net::HTTP

    def request(req, body=nil, opts={}, &block)  # :yield: +response+
      unless started?
        start {
          req['connection'] ||= 'close'
          return request(req, body, &block)
        }
      end
      if proxy_user()
        req.proxy_basic_auth proxy_user(), proxy_pass() unless use_ssl?
      end
      req.set_body_internal body
      res = transport_request(req, true, opts, &block)
      if sspi_auth?(res)
        sspi_auth(req)
        res = transport_request(req, true, opts, &block)
      end
      res
    end


    private

    def transport_request(req, allow_retry=true, opts={})
      # Check if previous request was made on same socket and needs
      # to be completed before we can read the new response.
      if Kronk::BufferedIO === @socket && !@socket.response.read?
        @socket.response.body
      end

      begin_transport req
      req.exec @socket, @curr_http_version, edit_path(req.path)

      begin
        opts[:timeout] ||= @socket.read_timeout
        res = Kronk::Response.new(@socket.io, opts)
      end while kronk_resp_type(res) == Net::HTTPContinue

      if res.headless?
        raise Net::HTTPBadResponse, "Invalid HTTP response" unless allow_retry
        @socket.io.close
        res = transport_request(req, false, opts)
      end

      @socket = res.io

      res.body {|r, chunk|
        yield r, chunk
      } if block_given?

      end_transport req, res
      res

    rescue => exception
      D "Conn close because of error #{exception}"
      @socket.close if @socket and not @socket.closed?
      raise exception
    end


    def end_transport(req, res)
      @curr_http_version = res.http_version
      if @socket.closed?
        D 'Conn socket closed'
      elsif keep_alive?(req, res)
        D 'Conn keep-alive'
      elsif not res.body and @close_on_empty_response
        D 'Conn close'
        @socket.close
      else
        D 'Conn close'
        @socket.close
      end
    end


    def sspi_auth?(res)
      return false unless @sspi_enabled
      if kronk_resp_type(res) == HTTPProxyAuthenticationRequired and
          proxy? and res["Proxy-Authenticate"].include?("Negotiate")
        begin
          require 'win32/sspi'
          true
        rescue LoadError
          false
        end
      else
        false
      end
    end


    def kronk_resp_type res
      Net::HTTPResponse::CODE_TO_OBJ[res.code]
    end
  end
end
