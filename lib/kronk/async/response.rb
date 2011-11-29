class Kronk
  class Response

    class AsyncHandler < EM::Connection
      attr_accessor :buffer

      def initialize opts
        @buffer   = ""
        @callback = nil
        @opts     = opts
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

        @_res = Kronk::Response.new @buffer, @opts
        err = Kronk::Request::EMError.new "IO read error" if error?

        @callback.call @_res, err

      rescue => e
        @callback.call @_res, e
      end
    end


    ##
    # Response.new with asynchronous IO input.
    # Returns an EM::Connection subclass (AsyncHandler) instance.
    #
    # Passing a block will yield a Kronk::Response instance and/or
    # an Exception instance if an error was caught.
    #
    #   conn = Response.from_async_io do |resp, err|
    #     # do something with Kronk::Response instance here
    #   end

    def self.from_async_io io, opts={}, &block
      conn = EM.attach io, AsyncHandler, opts
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
      Request.new(self.location, opts).retrieve_async(opts, &block)
    end
  end
end
