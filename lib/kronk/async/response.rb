class Kronk
  class Response

    ##
    # Follow the redirect and return a new Response instance.
    # Returns nil if not redirect-able.

    def follow_redirect_async opts={}, &block
      return if !redirect?
      loc = @_res['Location']
      Request.new(loc, opts).retrieve_async &block
    end
  end
end
