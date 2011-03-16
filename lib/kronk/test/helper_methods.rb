class Kronk

  ##
  # Kronk test helper methods to easily make and mock requests.
  # Sets @response, @data, and @diff instance variables.

  module HelperMethods

    ##
    # Do a get request for one or two URIs.
    # See Kronk#compare for all supported options.

    def get uri1, uri2=nil, options={}
      uri2, options = nil, uri2 if Hash === uri2
      retrieve uri1, uri2, options.merge(:http_method => :get)
    end


    ##
    # Do a post request for one or two URIs.
    # See Kronk#compare for all supported options.

    def post uri1, uri2=nil, options={}
      uri2, options = nil, uri2 if Hash === uri2
      retrieve uri1, uri2, options.merge(:http_method => :post)
    end


    ##
    # Do a put request for one or two URIs.
    # See Kronk#compare for all supported options.

    def put uri1, uri2=nil, options={}
      uri2, options = nil, uri2 if Hash === uri2
      retrieve uri1, uri2, options.merge(:http_method => :put)
    end


    ##
    # Do a delete request for one or two URIs.
    # See Kronk#compare for all supported options.

    def delete uri1, uri2=nil, options={}
      uri2, options = nil, uri2 if Hash === uri2
      retrieve uri1, uri2, options.merge(:http_method => :delete)
    end


    ##
    # Set a mock http response for a given uri.
    # Uri argument must be a String or Regexp.
    # Response argument must be a String or IO.

    def mock_http_response uri, mock_response
      @_kronk_mocks ||= {}
      @_kronk_mocks[uri] = mock_response
    end


    protected

    def retrieve uri1, uri2, options={}
      if uri2
        @response = [Request.retrieve(uri1, options),
                     Request.retrieve(uri2, options)]

        @data     = @response.map{|r| r.selective_data options}
        @diff     = Diff.new_from_data(*@data)

      else
        @response = Request.retrieve uri1, options
        @data     = @response.selective_data options
        @diff     = nil
      end
    end
  end
end
