require 'rubygems' if RUBY_VERSION =~ /1.8/

require 'json'
require 'cookiejar'
require 'path'

require 'thread'
require 'stringio'

require 'net/http'
require 'yaml'

class Kronk

  # This gem's version.
  VERSION = '1.8.7'

  require 'kronk/constants'
  require 'kronk/queue_runner'
  require 'kronk/player'
  require 'kronk/player/suite'
  require 'kronk/player/stream'
  require 'kronk/player/benchmark'
  require 'kronk/player/tsv'
  require 'kronk/player/request_parser'
  require 'kronk/player/input_reader'
  require 'kronk/data_string'
  require 'kronk/diff/ascii_format'
  require 'kronk/diff/color_format'
  require 'kronk/diff/output'
  require 'kronk/diff'
  require 'kronk/http'
  require 'kronk/buffered_io'
  require 'kronk/request'
  require 'kronk/response'
  require 'kronk/plist_parser'
  require 'kronk/xml_parser'
  require 'kronk/yaml_parser'


  ##
  # Read the Kronk config hash.

  def self.config
    @config ||= DEFAULT_CONFIG
  end


  ##
  # Load a config file and apply to Kronk.config.

  def self.load_config filepath=DEFAULT_CONFIG_FILE
    conf = YAML.load_file filepath

    conf.each do |key, value|
      skey = key.to_sym

      case skey
      when :content_types, :user_agents
        conf[key].each{|k,v| self.config[skey][k.to_s] = v }

      when :requires
        self.config[skey].concat Array(value)

      when :uri_options
        conf[key].each do |matcher, opts|
          self.config[skey][matcher.to_s] = opts
          opts.keys.each{|k| opts[k.to_sym] = opts.delete(k) if String === k}
        end

      else
        self.config[skey] = value
      end
    end
  end


  ##
  # Find a fully qualified ruby namespace/constant. Supports file paths,
  # constants, or path:Constant combinations:
  #   Kronk.find_const "json"
  #   #=> JSON
  #
  #   Kronk.find_const "namespace/mylib"
  #   #=> Namespace::MyLib
  #
  #   Kronk.find_const "path/to/somefile.rb:Namespace::MyLib"
  #   #=> Namespace::MyLib

  def self.find_const name_or_file, case_insensitive=false
    return name_or_file unless String === name_or_file

    if name_or_file =~ /[^:]:([^:]+)$/
      req_file = $1
      i        = $1.length + 2
      const    = name_or_file[0..-i]

      begin
        require req_file
      rescue LoadError
        require File.expand_path(req_file)
      end

      find_const const

    elsif name_or_file.include? File::SEPARATOR
      begin
        require name_or_file
      rescue LoadError
        require File.expand_path(name_or_file)
      end

      namespace = File.basename name_or_file, ".rb"
      consts    = File.dirname(name_or_file).split(File::SEPARATOR)
      consts   << namespace

      name = ""
      until consts.empty?
        name  = "::" << consts.pop.to_s << name
        const = find_const name, true rescue nil
        return const if const
      end

      raise NameError, "no constant match for #{name_or_file}"

    else
      consts = name_or_file.to_s.split "::"
      curr = self

      until consts.empty? do
        const = consts.shift
        next if const.to_s.empty?

        if case_insensitive
          const.gsub!(/(^|[\-_.]+)([a-z0-9])/i){|m| m[-1,1].upcase}
          const = (curr.constants | Object.constants).find do |c|
            c.to_s.downcase == const.to_s.downcase
          end
        end

        curr = curr.const_get const.to_s
      end

      curr
    end
  end


  ##
  # Returns the config-defined parser class for a given content type.

  def self.parser_for content_type
    parser_pair =
      config[:content_types].select do |key, value|
        (content_type =~ %r{#{key}([^\w]|$)}) && value
      end.to_a

    return if parser_pair.empty?

    parser = parser_pair[0][1]
    parser = find_const parser if String === parser || Symbol === parser
    parser
  end


  ##
  # Deletes all cookies from the runtime.
  # If Kronk.run is in use, will write the change to the cookies file as well.

  def self.clear_cookies!
    @cookie_jar = CookieJar::Jar.new
  end


  ##
  # Returns the kronk cookie jar.

  def self.cookie_jar
    @cookie_jar ||= load_cookie_jar
  end


  ##
  # Load the saved cookies file. Defaults to Kronk::config[:cookies_file].

  def self.load_cookie_jar file=nil
    file ||= config[:cookies_file]
    @cookie_jar = YAML.load_file file if File.file? file
    @cookie_jar ||= CookieJar::Jar.new
    @cookie_jar.expire_cookies
    @cookie_jar
  end


  ##
  # Save the cookie jar to file.

  def self.save_cookie_jar file=nil
    file ||= config[:cookies_file]
    File.open(file, "w") do |f|
      f.write @cookie_jar.to_yaml
    end
  end


  ##
  # Returns the Kronk history array of accessed URLs.

  def self.history
    path = self.config[:history_file]
    @history ||= File.read(path).split($/) if File.file?(path)
    @history ||= []
    @history
  end


  ##
  # Writes the URL history to the history file.

  def self.save_history
    history_str = self.history.uniq[0..self.config[:max_history]].join($/)

    File.open self.config[:history_file], "w" do |file|
      file.write history_str
    end
  end


  ##
  # Returns an array of middleware to use around requests.

  def self.middleware
    @middleware ||= []
  end


  ##
  # Assign middleware to use.

  def self.use mware
    self.middleware.unshift mware
  end


  ##
  # See Kronk#compare. Short for:
  #   Kronk.new(opts).compare(uri1, uri2)

  def self.compare uri1, uri2, opts={}
    new(opts).compare uri1, uri2
  end


  ##
  # See Kronk#request. Short for:
  #   Kronk.new(opts).request(uri)

  def self.request uri, opts={}
    new(opts).request uri
  end

  class << self
    alias retrieve request
  end

  attr_accessor :diff, :options, :response, :responses


  ##
  # Create a Kronk instance to keep references to all request, response,
  # and diff data.
  #
  # Supports the following options:
  # :data:: Hash/String - the data to pass to the http request
  # :query:: Hash/String - the data to append to the http request path
  # :follow_redirects:: Integer/Boolean - number of times to follow redirects
  # :headers:: Hash - extra headers to pass to the request
  # :http_method:: Symbol - the http method to use; defaults to :get
  # :user_agent:: String - user agent string or alias; defaults to 'kronk'
  # :auth:: Hash - must contain :username and :password; defaults to nil
  # :proxy:: Hash/String - http proxy to use; defaults to nil
  # :keep_indicies:: Boolean - indicies of modified arrays display as hashes
  # :show_headers:: Boolean/String/Array - which headers to show in output
  # :parser:: Object/String - the parser to use for the body; default nil
  # :raw:: Boolean - run diff on raw strings
  # :transform:: Array - Action/path(s) pairs to modify data.
  #
  # Deprecated Options:
  # :ignore_data:: String/Array - Removes the data from given data paths
  # :only_data:: String/Array - Extracts the data from given data paths

  def initialize opts={}
    @options   = opts
    @diff      = nil
    @responses = []
    @response  = nil

    meth = method(:request_explicit)
    @app = Kronk.middleware.inject(meth){|app, mware| mware.new(app) }
  end


  ##
  # Make requests, parse the responses and compare the data.
  # Query arguments may be set to the special value :cache to use the
  # last live http response retrieved.
  #
  # Assigns @response, @responses, @diff. Returns the Diff instance.

  def compare uri1, uri2
    str1 = str2 = ""
    res1 = res2 = nil

    t1 = Thread.new do
          res1 = request uri1
          str1 = res1.stringify
         end

    t2 = Thread.new do
          res2 = request uri2
          str2 = res2.stringify
         end

    t1.join
    t2.join

    @responses = [res1, res2]
    @response  = res2

    opts = {:labels => [res1.uri, res2.uri]}.merge @options
    @diff = Diff.new str1, str2, opts
  end


  ##
  # Returns a Response instance from a url, file, or IO as a String.
  # Assigns @response, @responses, @diff.

  def request uri
    options = Kronk.config[:no_uri_options] ? @options : options_for_uri(uri)
    options.merge!(:uri => uri)

    resp = @app.call options

    rdir = options[:follow_redirects]
    while resp.redirect? && (rdir == true || rdir.to_s.to_i > 0)
      uri = resp.location
      Cmd.verbose "Following redirect to #{resp.location}"
      resp = resp.follow_redirect options_for_uri(resp.location)
      rdir = rdir - 1 if Fixnum === rdir
    end

    resp.parser         = options[:parser] if options[:parser]
    resp.stringify_opts = options

    @responses = [resp]
    @response  = resp
    @diff      = nil

    resp

  rescue SocketError, SystemCallError => e
    raise NotFoundError, "#{uri} could not be found (#{e.class})"

  rescue Timeout::Error
    raise TimeoutError, "#{uri} took too long to respond"
  end

  alias retrieve request


  ##
  # Request without autofilling options.

  def request_explicit opts
    uri = opts.delete(:uri)

    if IO === uri || StringIO === uri || BufferedIO === uri
      Cmd.verbose "Reading IO #{uri}"
      Response.new uri, options

    elsif File.file? uri.to_s
      Cmd.verbose "Reading file:  #{uri}\n"
      Response.read_file uri, options

    else
      req = Request.new uri, options
      Cmd.verbose "Retrieving URL:  #{req.uri}\n"
      resp = req.retrieve options

      hist_uri = req.uri.to_s[0..-req.uri.request_uri.length]
      hist_uri = hist_uri[(req.uri.scheme.length + 3)..-1]
      Kronk.history << hist_uri

      resp
    end
  end


  ##
  # Returns merged config-defined options for a given uri.
  # Values in cmd_opts take precedence.
  # Returns cmd_opts Hash if none found.

  def options_for_uri uri
    out_opts = @options.dup

    Kronk.config[:uri_options].each do |matcher, opts|
      next unless (uri == matcher || uri =~ %r{#{matcher}}) && Hash === opts

      opts.each do |key, val|
        if out_opts[key].nil?
          out_opts[key] = val
          next
        end

        case key

        # Hash or uri query String
        when :data, :query
          val = Request.parse_nested_query val if String === val

          out_opts[key] = Request.parse_nested_query out_opts[key] if
            String === out_opts[key]

          out_opts[key] = val.merge out_opts[key], &DEEP_MERGE

        # Hashes
        when :headers, :auth
          out_opts[key] = val.merge out_opts[key]

        # Proxy hash or String
        when :proxy
          if Hash === val && Hash === out_opts[key]
            out_opts[key] = val.merge out_opts[key]

          elsif Hash === val && String === out_opts[key]
            val[:address] = out_opts[key]
            out_opts[key] = val

          elsif String === val && Hash === out_opts[key]
            out_opts[key][:address] ||= val
          end

        # Response headers - Boolean, String, or Array
        when :show_headers
          next if out_opts.has_key?(key) &&
                  (out_opts[key].class != Array || val == true || val == false)
          out_opts[key] = (val == true || val == false) ? val :
                                      [*out_opts[key]] | [*val]

        # String or Array
        when :only_data, :ignore_data
          out_opts[key] = [*out_opts[key]] | [*val]
        end
      end
    end

    out_opts
  end
end
