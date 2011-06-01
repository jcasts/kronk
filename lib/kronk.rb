require 'rubygems'

require 'json'
require 'cookiejar'
require 'rack'

require 'net/https'
require 'optparse'
require 'yaml'

class Kronk

  # This gem's version.
  VERSION = '1.3.1'


  require 'kronk/cmd'
  require 'kronk/data_set'
  require 'kronk/diff/ascii_format'
  require 'kronk/diff/color_format'
  require 'kronk/diff'
  require 'kronk/response'
  require 'kronk/request'
  require 'kronk/plist_parser'
  require 'kronk/xml_parser'


  # Config directory.
  CONFIG_DIR = File.expand_path "~/.kronk"

  # Default config file to load. Defaults to ~/.kronk.
  DEFAULT_CONFIG_FILE = File.join CONFIG_DIR, "rc"

  # Default cache file.
  DEFAULT_CACHE_FILE = File.join CONFIG_DIR, "cache"

  # Default cookies file.
  DEFAULT_COOKIES_FILE = File.join CONFIG_DIR, "cookies"

  # Default file with history of unique URIs. (Used for autocomplete)
  DEFAULT_HISTORY_FILE = File.join CONFIG_DIR, "history"


  # Default Content-Type header to parser mapping.
  DEFAULT_CONTENT_TYPES = {
    'js'      => 'JSON',
    'json'    => 'JSON',
    'plist'   => 'PlistParser',
    'xml'     => 'XMLParser'
  }


  # Aliases for various user-agents. Thanks Mechanize! :)
  USER_AGENTS = {
    'kronk'         =>
    "Kronk/#{VERSION} (http://github.com/yaksnrainbows/kronk)",
    'iphone'        =>
    "Mozilla/5.0 (iPhone; U; CPU like Mac OS X; en) AppleWebKit/420+ (KHTML, like Gecko) Version/3.0 Mobile/1C28 Safari/419.3",
    'linux_firefox' =>
    "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.2.1) Gecko/20100122 firefox/3.6.1",
    'linux_mozilla' =>
    "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030624",
    'mac_mozilla'   =>
    "Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.4a) Gecko/20030401",
    'linux_konqueror' =>
    "Mozilla/5.0 (compatible; Konqueror/3; Linux)",
    'mac_firefox'   =>
    "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.6; en-US; rv:1.9.2) Gecko/20100115 Firefox/3.6",
    'mac_safari'    =>
    "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_2; de-at) AppleWebKit/531.21.8 (KHTML, like Gecko) Version/4.0.4 Safari/531.21.10",
    'win_ie6'       =>
    "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)",
    'win_ie7'       =>
    "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322; .NET CLR 2.0.50727)",
    'win_mozilla'   =>
    "Mozilla/5.0 (Windows; U; Windows NT 5.0; en-US; rv:1.4b) Gecko/20030516 Mozilla Firebird/0.6"
  }


  # Default config to use.
  DEFAULT_CONFIG = {
    :content_types  => DEFAULT_CONTENT_TYPES.dup,
    :cache_file     => DEFAULT_CACHE_FILE,
    :cookies_file   => DEFAULT_COOKIES_FILE,
    :default_host   => "http://localhost:3000",
    :diff_format    => :ascii_diff,
    :history_file   => DEFAULT_HISTORY_FILE,
    :requires       => [],
    :show_lines     => false,
    :uri_options    => {},
    :use_cookies    => true,
    :user_agents    => USER_AGENTS.dup
  }


  ##
  # Read the Kronk config hash.

  def self.config
    @config ||= DEFAULT_CONFIG
  end


  ##
  # Load a config file and apply to Kronk.config.

  def self.load_config filepath=DEFAULT_CONFIG_FILE
    conf          = YAML.load_file DEFAULT_CONFIG_FILE
    content_types = conf.delete :content_types
    uri_options   = conf.delete :uri_options
    user_agents   = conf.delete :user_agents

    if conf[:requires]
      requires = [*conf.delete(:requires)]
      self.config[:requires] ||= []
      self.config[:requires].concat requires
    end

    self.config[:uri_options].merge! uri_options     if uri_options
    self.config[:content_types].merge! content_types if content_types
    self.config[:user_agents].merge! user_agents     if user_agents

    self.config.merge! conf
  end


  ##
  # Load the config-based requires.

  def self.load_requires more_requires=nil
    return unless config[:requires] || more_requires
    (config[:requires] | more_requires.to_a).each{|lib| require lib }
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
  # Returns merged config-defined options for a given uri.
  # Values in cmd_opts take precedence.
  # Returns cmd_opts Hash if none found.

  def self.merge_options_for_uri uri, cmd_opts={}
    return cmd_opts if Kronk.config[:no_uri_options]

    out_opts = Hash.new.merge cmd_opts

    Kronk.config[:uri_options].each do |matcher, opts|
      next unless (uri == matcher || uri =~ %r{#{matcher}}) && Hash === opts

      opts.each do |key, val|
        if !out_opts[key]
          out_opts[key] = val
          next
        end


        case key

        # Hash or uri query String
        when :data, :query
          val = Rack::Utils.parse_nested_query val if String === val

          out_opts[key] = Rack::Utils.parse_nested_query out_opts[key] if
            String === out_opts[key]

          out_opts[key] = val.merge out_opts[key], &DataSet::DEEP_MERGE

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
        when :only_data, :only_data_with, :ignore_data, :ignore_data_with
          out_opts[key] = [*out_opts[key]] | [*val]
        end
      end
    end

    out_opts
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
  # Make requests, parse the responses and compare the data.
  # Query arguments may be set to the special value :cache to use the
  # last live http response retrieved.
  #
  # Supports the following options:
  # :data:: Hash/String - the data to pass to the http request
  # :query:: Hash/String - the data to append to the http request path
  # :follow_redirects:: Integer/Bool - number of times to follow redirects
  # :headers:: Hash - extra headers to pass to the request
  # :http_method:: Symbol - the http method to use; defaults to :get
  # :user_agent:: String - user agent string or alias; defaults to 'kronk'
  # :auth:: Hash - must contain :username and :password; defaults to nil
  # :proxy:: Hash/String - http proxy to use; defaults to nil
  # :only_data:: String/Array - extracts the data from given data paths
  # :only_data_with:: String/Array - extracts the data from given parent paths
  # :ignore_data:: String/Array - defines which data points to exclude
  # :ignore_data_with:: String/Array - defines which parent data to exclude
  # :with_headers:: Bool/String/Array - defines which headers to include
  # :parser:: Object/String - The parser to use for the body; default nil
  # :raw:: Bool - run diff on raw strings
  #
  # Returns a diff object.

  def self.compare uri1, uri2, options={}
    str1 = retrieve_data_string uri1, options
    str2 = retrieve_data_string uri2, options

    Diff.new str1, str2
  end


  ##
  # Return a data string, parsed or raw.
  # See Kronk.compare for supported options.

  def self.retrieve_data_string uri, options={}
    options = merge_options_for_uri uri, options

    resp = Request.retrieve uri, options

    if options[:irb]
      irb resp

    elsif options[:raw]
      resp.selective_string options

    else
      begin
        data = resp.selective_data options
        Diff.ordered_data_string data, options[:struct]

      rescue Response::MissingParser
        Cmd.verbose "Warning: No parser for #{resp['Content-Type']} [#{uri}]"
        resp.selective_string options
      end
    end
  end


  ###
  # Deprecated methods...
  ###


  def self.deprecated method_name, replacement=nil
    replacement &&= ", use #{replacement}"
    replacement ||= " with no replacement"

    Cmd.warn "#{method_name} deprecated#{replacement}"
  end


  ##
  # Deprecated! Use Kronk::Cmd::irb

  def self.irb resp
    deprecated "Kronk::irb", "Kronk::Cmd::irb"
    Cmd.irb resp
  end


  ##
  # Deprecated! Use Kronk::Cmd::move_config_file

  def self.move_config_file
    deprecated "Kronk::move_config_file", "Kronk::Cmd::move_config_file"
    Cmd.move_config_file
  end


  ##
  # Deprecated! Use Kronk::Cmd::query_password

  def self.query_password str=nil
    deprecated "Kronk::query_password", "Kronk::Cmd::query_password"
    Cmd.query_password str
  end


  ##
  # Deprecated! Use Kronk::Cmd::parse_args

  def self.parse_args argv
    deprecated "Kronk::parse_args", "Kronk::Cmd::parse_args"
    Cmd.parse_args argv
  end


  ##
  # Deprecated! Use Kronk::Cmd::parse_data_path_args

  def self.parse_data_path_args options, argv
    deprecated "Kronk::parse_data_path_args", "Kronk::Cmd::parse_data_path_args"
    Cmd.parse_data_path_args options, argv
  end


  ##
  # Deprecated! Use Kronk::Cmd::run

  def self.run argv=ARGV
    deprecated "Kronk::run", "Kronk::Cmd::run"
    Cmd.run argv
  end


  ##
  # Deprecated! Use Kronk::Cmd::verbose

  def self.verbose str
    deprecated "Kronk::verbose", "Kronk::Cmd::verbose"
    Cmd.verbose str
  end


  ##
  # Deprecated! Use Kronk::Cmd::windows?

  def self.windows?
    deprecated "Kronk::windows?", "Kronk::Cmd::windows?"
    Cmd.windows?
  end
end
