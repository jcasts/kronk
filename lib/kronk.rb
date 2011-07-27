require 'rubygems'

require 'json'
require 'cookiejar'

require 'net/https'
require 'optparse'
require 'yaml'

class Kronk

  # This gem's version.
  VERSION = '1.5.0'

  require 'kronk/constants'
  require 'kronk/player'
  require 'kronk/player/output'
  require 'kronk/player/suite_output'
  require 'kronk/player/stream_output'
  require 'kronk/cmd'
  require 'kronk/path'
  require 'kronk/path/transaction'
  require 'kronk/diff/ascii_format'
  require 'kronk/diff/color_format'
  require 'kronk/diff'
  require 'kronk/response'
  require 'kronk/request'
  require 'kronk/plist_parser'
  require 'kronk/xml_parser'


  ##
  # Read the Kronk config hash.

  def self.config
    @config ||= DEFAULT_CONFIG
  end


  ##
  # Load a config file and apply to Kronk.config.

  def self.load_config filepath=DEFAULT_CONFIG_FILE
    conf = YAML.load_file DEFAULT_CONFIG_FILE

    self.config[:requires].concat [*conf.delete(:requires)] if conf[:requires]

    [:content_types, :uri_options, :user_agents].each do |key|
      self.config[key].merge! conf.delete(key) if conf[key]
    end

    self.config.merge! conf
  end


  ##
  # Load the config-based requires.

  def self.load_requires more_requires=nil
    return unless config[:requires] || more_requires
    (config[:requires] | [*more_requires]).each{|lib| require lib }
  end


  ##
  # Creates the default config file at the given path.

  def self.make_config_file
    Dir.mkdir CONFIG_DIR unless File.directory? CONFIG_DIR

    File.open DEFAULT_CONFIG_FILE, "w+" do |file|
      file << DEFAULT_CONFIG.to_yaml
    end
  end


  ##
  # Find a fully qualified ruby namespace/constant.

  def self.find_const namespace
    consts = namespace.to_s.split "::"
    curr = self

    until consts.empty? do
      curr = curr.const_get consts.shift
    end

    curr
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
  # Load the saved cookies file.

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
    history_str = self.history.uniq.join($/)

    File.open self.config[:history_file], "w" do |file|
      file.write history_str
    end
  end


  ##
  # See Kronk#compare. Short for:
  #   Kronk.new(opts).compare(uri1, uri2)

  def self.compare uri1, uri2, opts={}
    new(opts).compare uri1, uri2
  end


  ##
  # See Kronk#retrieve. Short for:
  #   Kronk.new(opts).retrieve(uri)

  def self.retrieve uri, opts={}
    new(opts).retrieve uri
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
  # :only_data:: String/Array - extracts the data from given data paths
  # :ignore_data:: String/Array - defines which data points to exclude
  # :keep_indicies:: Boolean - keep the original indicies of modified arrays,
  #   and return them as hashes.
  # :with_headers:: Boolean/String/Array - defines which headers to include
  # :parser:: Object/String - the parser to use for the body; default nil
  # :raw:: Boolean - run diff on raw strings
  # :cache_response:: String - the filepath to save the raw response to

  def initialize opts={}
    @options   = opts
    @diff      = nil
    @responses = []
    @response  = nil
  end


  ##
  # Make requests, parse the responses and compare the data.
  # Query arguments may be set to the special value :cache to use the
  # last live http response retrieved.
  #
  # Returns a diff object.

  def compare uri1, uri2
    str1 = str2 = ""
    res1 = res2 = nil

    t1 = Thread.new do
          res1 = retrieve uri1, false
          str1 = res1.stringify @options
         end

    t2 = Thread.new do
          res2 = retrieve uri2, false
          str2 = res2.stringify @options
         end

    t1.join
    t2.join

    post_process_responses res1, res2
    @diff = Diff.new str1, str2
  end


  ##
  # Returns a Response instance from a url, file, or IO as a String.

  def retrieve uri, do_post_process=true
    options = Kronk.config[:no_uri_options] ? options_for_uri(uri) : @options

    if IO === uri || StringIO === uri
      Cmd.verbose "Reading IO #{uri}"
      resp = Response.new uri

    elsif File.file? uri.to_s
      Cmd.verbose "Reading file:  #{uri}\n"
      resp = Response.read_file uri

    else
      req = Request.new uri, options
      Cmd.verbose "Retrieving URL:  #{req.uri}\n"
      resp = req.retrieve
      Kronk.history << uri
    end

    max_rdir = options[:follow_redirects]
    while resp.redirect? && (max_rdir == true || max_rdir.to_i > 0)
      Cmd.verbose "Following redirect..."
      resp     = resp.follow_redirect
      max_rdir = max_rdir - 1 if Fixnum === max_rdir
    end

    post_process_responses resp if do_post_process
    resp

  rescue SocketError, Errno::ENOENT, Errno::ECONNREFUSED
    raise NotFoundError, "#{uri} could not be found"

  rescue Timeout::Error
    raise TimeoutError, "#{uri} took too long to respond"
  end


  ##
  # Saves the raw http response to a cache file.

  def cache_response resp=@response
    return unless @options[:cache_response]
    filepath = @options[:cache_response]

    begin
      File.open(filepath, "wb+") do |file|
        file.write resp.raw
      end
    rescue => e
      $stderr << "#{e.class}: #{e.message}"
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
        when :with_headers
          next if out_opts[key] == true || out_opts[key] && val == true
          out_opts[key] = [*out_opts[key]] | [*val]

        # String or Array
        when :only_data, :ignore_data
          out_opts[key] = [*out_opts[key]] | [*val]
        end
      end
    end

    out_opts
  end


  ##
  # Assign responses to instance variables, cache the last
  # response, and launch IRB if needed.

  def post_process_responses *resps
    @responses = resps
    @response  = resps.last
    cache_response
    Cmd.irb resp if @options[:irb]
  end
end
