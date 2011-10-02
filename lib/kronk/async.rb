require 'kronk'
require 'kronk/async/em_ext'
require 'kronk/async/request'
require 'kronk/async/response'

class Kronk

  ##
  # Returns an EventMachine Connection instance from a url, file, or IO.
  # Calls the given block with a Kronk::Response object on completion or error.
  # Assigns @response, @responses, @diff. Must be called from an EM loop.
  #
  #   kronk.request_async do |kronk, err|
  #     # handle response or error
  #   end

  def request_async uri
    options = Kronk.config[:no_uri_options] ? @options : options_for_uri(uri)

    rdir = options[:follow_redirects]

    handler = Proc.new do |resp|
      Kronk.history << resp.request.uri if resp.request

      resp.parser         = options[:parser] if options[:parser]
      resp.stringify_opts = options

      if resp.redirect? && (rdir == true || Fixnum === rdir && rdir > 0)
        Cmd.verbose "Following redirect to #{resp['LOCATION']}"
        resp.follow_redirect_async &handler
        rdir = rdir - 1 if Fixnum === rdir

      else
        @responses = [resp]
        @response  = resp
        @diff      = nil

        yield self if block_given?

        resp
      end
    end

    # TODO: read from IOs asynchronously.

    if IO === uri || StringIO === uri
      Cmd.verbose "Reading IO #{uri}"
      resp = Response.new uri

    elsif File.file? uri.to_s
      Cmd.verbose "Reading file:  #{uri}\n"
      resp = Response.read_file uri

    else
      req = Request.new uri, options
      Cmd.verbose "Retrieving URL:  #{req.uri}\n"

      conn = req.retrieve_async &handler
    end

  rescue => e
    yield self, e
  end
end
