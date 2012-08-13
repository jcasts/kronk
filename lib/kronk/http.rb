class Kronk

  class HTTPBadResponse < Net::HTTPBadResponse; end

  ##
  # Wrapper for Net::HTTP

  class HTTP < Net::HTTP

    class << self
      # Total number of http connections ever created.
      attr_accessor :total_conn
    end

    self.total_conn = 0

    # Pool of open connections.
    CONN_POOL = Hash.new{|h,k| h[k] = []}

    # Connections currently in use
    CONN_USED = {}

    # Max time a pool should hold onto an open connection.
    MAX_CONN_AGE = 10

    C_MUTEX    = Mutex.new
    M_MUTEX    = Mutex.new
    POOL_MUTEX = Hash.new{|h,k| M_MUTEX.synchronize{ h[k] = Mutex.new} }


    # Last time this http connection was used
    attr_accessor :last_used


    ##
    # Create a new http connection or get an existing, unused keep-alive
    # connection. Supports the following options:
    # :poxy:: String or Hash with proxy settings (see Kronk::Request)
    # :ssl::  Boolean specifying whether to use SSL or not

    def self.new(address, port=nil, opts={})
      port ||= HTTP.default_port
      proxy  = opts[:proxy] || {}

      conn_id = [address, port, !!opts[:ssl],
                  proxy[:host], proxy[:port], proxy[:username]]

      conn = get_conn(conn_id)

      if !conn
        conn  = super(address, port, proxy[:host], proxy[:port],
                        proxy[:username], proxy[:password])

        if opts[:ssl]
          require 'net/https'
          conn.use_ssl = true
        end

        C_MUTEX.synchronize{ @total_conn += 1 }
      end

      CONN_USED[conn] = true

      conn
    end


    ##
    # Total number of currently active connections.

    def self.conn_count
      M_MUTEX.synchronize do
        CONN_USED.length + CONN_POOL.values.flatten.length
      end
    end


    ##
    # Get a connection from the pool based on a connection id.
    # Connection ids are an Array with the following values:
    #   [addr, port, ssl, proxy_addr, proxy_port, proxy_username]

    def self.get_conn(conn_id)
      conn = nil
      pool = CONN_POOL[conn_id]

      POOL_MUTEX[conn_id].synchronize do
        while !pool.empty? && (!conn || conn.closed? || conn.outdated?)
          conn = pool.shift
        end
      end

      conn
    end


    ##
    # Put this http connection in the pool for use by another request.

    def add_to_pool
      return if closed? || outdated?
      conn_id = [@address, @port, @use_ssl,
                  proxy_address, proxy_port, proxy_user]

      POOL_MUTEX[conn_id].synchronize do
        CONN_POOL[conn_id] << self
      end
    end


    ##
    # Returns true if this connection was last used more than
    # MAX_CONN_AGE seconds ago.

    def outdated?
      Time.now - @last_used > MAX_CONN_AGE
    end


    ##
    # Check if the socket for this http connection can be read and written to.

    def closed?
      !@socket || @socket.closed?
    end


    ##
    # Make an http request on the connection. Takes a Net::HTTP request instance
    # for the `req' argument.

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
        res.after_read{ add_to_pool }
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
