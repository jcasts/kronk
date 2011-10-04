require 'kronk'
require 'kronk/async/em_ext'
require 'kronk/async/request'
require 'kronk/async/response'

class Kronk

  ##
  # Returns an EM::MultiRequest instance from a url, file, or IO pair.
  # Calls the given block with a Kronk::Response object on completion or error.
  # Assigns @response, @responses, @diff. Must be called from an EM loop.
  #
  #   kronk.compare_async uri1, uri2 do |diff, err|
  #     # handle diff, responses, or error
  #   end

  def compare_async uri1, uri2
    multi = EM::MultiRequest.new

    str1 = str2 = ""
    res1 = res2 = nil
    err1 = err2 = nil

    conn1 = request_async uri1 do |res, err|
      err1 = err and next if err
      res1 = res
      str1 = res.stringify
    end

    conn2 = request_async uri2 do |res, err|
      err2 = err and next if err
      res2 = res
      str2 = res.stringify
    end

    multi.add :left,  conn1
    multi.add :right, conn2

    multi.callback do
      next yield(nil, (err1 || err2)) if err1 || err2

      @responses = [res1, res2]
      @response  = res2

      opts = {:labels => [res1.uri, res2.uri]}.merge @options
      @diff = Diff.new str1, str2, opts

      yield @diff
    end

    multi
  end


  ##
  # Returns an EventMachine Connection instance from a url, file, or IO.
  # Calls the given block with a Kronk::Response object on completion or error.
  # Assigns @response, @responses, @diff. Must be called from an EM loop.
  #
  #   kronk.request_async uri do |resp, err|
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

        rdir = rdir - 1 if Fixnum === rdir

        conn = resp.follow_redirect_async(&handler)
        conn.errback do |c|
          yield self, c.error
        end

      else
        @responses = [resp]
        @response  = resp
        @diff      = nil

        yield resp if block_given?

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

      conn = req.retrieve_async(&handler)
      conn.errback do |c|
        yield nil, c.error
      end
    end

  rescue => e
    yield nil, e
  end
end
