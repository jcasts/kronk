class Kronk
  class Response

    class AsyncHandler < EM::Connection
      attr_accessor :buffer

      def initialize req
        @buffer   = ""
        @callback = nil
        @_req     = req
        @_res     = nil
      end


      def callback &block
        @callback = block
      end


      def receive_data str
        @buffer << str
      end


      def unbind
        return unless @callback

        @_res = Kronk::Response.new @buffer, nil, @_req
        @callback.call @_res, nil

      rescue => e
        @callback.call @_res, e
      end
    end


    ##
    # Response.new with asynchronous IO input.
    #
    # Passing a block will yield a Kronk::Response instance and/or
    # an Exception instance if an error was caught.
    #
    # Returns an EM::Connection instance.

    def self.from_async_io io, req=nil, &block
      conn = EM.attach io, AsyncHandler, req
      conn.comm_inactivity_timeout = 2
      conn.callback(&block)
      conn
    end


    ##
    # Follow the redirect and return a new Response instance.
    # Returns nil if not redirect-able.
    #
    # Passing a block will yield a Kronk::Response instance and/or
    # an Exception instance if an error was caught.

    def follow_redirect_async opts={}, &block
      return if !redirect?
      Request.new(self.location, opts).retrieve_async(&block)
    end
  end
end
