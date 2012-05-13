class Kronk

  ##
  # Outputs Player results as a stream of Kronk outputs
  # in chunked form, each chunk being one response and the number
  # of octets being expressed in hexadecimal form.
  #
  #   out   = Player::StreamOutput.new
  #
  #   io1   = StringIO.new "this is the first chunk"
  #   io2   = StringIO.new "this is the rest"
  #
  #   kronk = Kronk.new
  #   kronk.request io1
  #   out.result kronk
  #   #=> "17\r\nthis is the first chunk\r\n"
  #
  #   kronk.request io2
  #   out.result kronk
  #   #=> "10\r\nthis is the rest\r\n"
  #
  # Note: This output class will not render errors.

  class Player::Download < Player

    # Directory to write the files to.
    attr_accessor :dir

    def initialize opts={}
      super

      @counter = 0
      @counter_mutex = Mutex.new

      require 'fileutils'

      default_dir = File.join Dir.pwd, "kronk-#{Time.now.to_i}"
      @dir        = File.expand_path(opts[:dir] || default_dir)

      FileUtils.mkdir_p @dir
    end


    def result kronk
      output, name, ext =
        if kronk.diff
          name = make_name kronk.responses[0].uri
          name = "#{name}-#{make_name kronk.responses[1].uri}"
          [kronk.diff.formatted, name, "diff"]

        elsif kronk.response
          name = make_name kronk.response.uri
          [kronk.response.stringify, name, ext_for(kronk.response)]
        end

      return unless output && !output.empty?

      filename = nil

      @counter_mutex.synchronize do
        @counter += 1
        filename = File.join(@dir, "#{@counter}-#{name}.#{ext}")
      end

      File.open(filename, "w"){|file| file.write output}

      @mutex.synchronize do
        $stdout.puts filename
      end
    end


    def make_name uri
      return unless uri
      parts = uri.path.to_s.sub(%r{^/}, "").split("/")
      parts = parts[-2..-1] || parts
      parts.join("-").sub(%r{[?.].*$}, "")
    end


    def ext_for resp
      if will_parse(resp)
        Kronk.config[:render_lang].to_s == "ruby" ? "rb" : "json"

      elsif resp.stringify_opts[:show_headers]
        "http"

      else
        resp.ext
      end
    end


    def will_parse resp
      (resp.parser || resp.stringify_opts[:parser] ||
       (resp.stringify_opts[:no_body] && resp.stringify_opts[:show_headers])) &&
        !resp.stringify_opts[:raw]
    end
  end
end

