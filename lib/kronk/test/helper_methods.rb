class Kronk

  module Test

    ##
    # Kronk test helper methods to easily make and mock requests.
    # Sets @responses, @response, @datas, @data, and @diff instance variables.

    module HelperMethods

      ##
      # Do a get request for one or two URIs.
      # See Kronk#compare for all supported options.

      def get uri1, uri2=nil, options={}
        retrieve uri1, uri2, options.merge(:http_method => :get)
      end


      ##
      # Do a post request for one or two URIs.
      # See Kronk#compare for all supported options.

      def post uri1, uri2=nil, options={}
        retrieve uri1, uri2, options.merge(:http_method => :post)
      end


      ##
      # Do a put request for one or two URIs.
      # See Kronk#compare for all supported options.

      def put uri1, uri2=nil, options={}
        retrieve uri1, uri2, options.merge(:http_method => :put)
      end


      ##
      # Do a delete request for one or two URIs.
      # See Kronk#compare for all supported options.

      def delete uri1, uri2=nil, options={}
        retrieve uri1, uri2, options.merge(:http_method => :delete)
      end


      protected

      def retrieve uri1, uri2=nil, options={}
        uri2, options = nil, uri2.merge(options) if Hash === uri2

        if uri2
          @responses = [Request.retrieve(uri1, options),
                        Request.retrieve(uri2, options)]
          @response  = @responses.last

          @datas     = @responses.map do |r|
                         begin
                           r.selective_data options
                         rescue Kronk::Response::MissingParser
                           r.body
                         end
                       end

          @data      = @datas.last

          @diff      = Diff.new_from_data(*@datas)

        else
          @response  = Request.retrieve uri1, options
          @responses = [@response]

          @data      = begin
                         @response.selective_data options
                       rescue Kronk::Response::MissingParser
                         @response.body
                       end

          @datas     = [@data]

          @diff      = nil
        end
      end
    end
  end
end
