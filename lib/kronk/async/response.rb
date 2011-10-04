class Kronk
  class Response

    # TODO: Response.new with async
    # def self.from_async_io io
    # end

    ##
    # Follow the redirect and return a new Response instance.
    # Returns nil if not redirect-able.

    def follow_redirect_async opts={}, &block
      return if !redirect?
      Request.new(self.location, opts).retrieve_async(&block)
    end
  end
end
