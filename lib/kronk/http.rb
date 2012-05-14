class Kronk

  class HTTPBadResponse < Net::HTTPBadResponse; end

  ##
  # Wrapper for Net::HTTP

  class HTTP < Net::HTTP

    class << self
      attr_accessor :total_conn
    end
    self.total_conn = 0

    # Pool of open connections
    CONN_POOL = Hash.new{|h,k| h[k] = []}

    CONN_USED = {}

    # Max time a pool should hold onto an open connection
    MAX_CONN_AGE = 10

    C_MUTEX    = Mutex.new
    M_MUTEX    = Mutex.new
    POOL_MUTEX = Hash.new{|h,k| M_MUTEX.synchronize{ h[k] = Mutex.new} }

    attr_accessor :last_used

    def self.new(address, port=nil, p_addr=nil, p_port=nil, p_user=nil, p_pass=nil)
      # TODO: Make this work with https and proxies
      conn = get_conn(address, port)
      if !conn
        conn = super
        C_MUTEX.synchronize{@total_conn += 1}
      end

      CONN_USED[conn] = true

      conn
    end


    def self.conn_count
      M_MUTEX.synchronize do
        CONN_USED.length + CONN_POOL.values.flatten.length
      end
    end


    def self.get_conn(address, port)
      conn = nil
      host = "#{address}:#{port}"
      pool = CONN_POOL[host]

      POOL_MUTEX[host].synchronize do
        while !pool.empty? && (!conn || conn.closed? || conn.outdated?)
          conn = pool.shift
        end
      end

      conn
    end


    def add_to_pool
      return if closed? || outdated?
      host = "#{@address}:#{@port}" # TODO: ADD PROTOCOL AND PROXY

      POOL_MUTEX[host].synchronize do
        CONN_POOL[host] << self
      end
    end


    def outdated?
      Time.now - @last_used > MAX_CONN_AGE
    end


    def closed?
      !@socket || @socket.closed?
    end


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
      if Kronk::BufferedIO === @socket
        @socket.response.send(:read_body, "") if @socket.response.body.nil?
        @socket.clear
      end

      begin_transport req
      req.exec @socket, @curr_http_version, edit_path(req.path)

      begin
        opts[:timeout] ||= @socket.read_timeout
        res = Kronk::Response.new(@socket.io, opts)
      end while kronk_resp_type(res) == Net::HTTPContinue

      if res.headless?
        raise HTTPBadResponse, "Invalid HTTP response" unless allow_retry
        @socket.io.close
        res = transport_request(req, false, opts)
      end

      @socket = res.io

      res.body {|chunk|
        yield res, chunk
      } if block_given?

      end_transport req, res
      res

    rescue => exception
      D "Conn close because of error #{exception}"
      @socket.close if @socket and not @socket.closed?
      raise exception
    end


    def end_transport(req, res)
      CONN_USED.delete self
      @last_used = Time.now
      @curr_http_version = res.http_version

      if @socket.closed?
        D 'Conn socket closed'
      elsif keep_alive?(req, res)
        D 'Conn keep-alive'
        add_to_pool
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
