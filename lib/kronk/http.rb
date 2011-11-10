class Kronk

  ##
  # Wrapper for Net::HTTP

  class HTTP < Net::HTTP

    attr_accessor :kronk_req

    def request(req, body = nil, &block)  # :yield: +response+
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
      res = transport_request(req, &block)
      if sspi_auth?(res)
        sspi_auth(req)
        res = transport_request(req, &block)
      end
      res
    end


    private

    def transport_request(req)
      begin_transport req
      req.exec @socket, @curr_http_version, edit_path(req.path)
      begin
        res = Kronk::Response.new(@socket, @kronk_req)
      end while kronk_resp_type(res) == Net::HTTPContinue

      end_transport req, res.instance_variable_get("@_res")
      res
    rescue => exception
      D "Conn close because of error #{exception}"
      @socket.close if @socket and not @socket.closed?
      raise exception
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
