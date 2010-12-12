require 'rubygems'
require 'plist'
require 'json'
require 'nokogiri'

# Support for new and old versions of ActiveSupport
begin
  require 'active_support/inflector'
rescue LoadError
  require 'activesupport'
end

require 'net/https'
require 'optparse'
require 'yaml'

class Kronk

  # This gem's version.
  VERSION = '1.0.3'


  require 'kronk/data_set'
  require 'kronk/diff'
  require 'kronk/response'
  require 'kronk/request'
  require 'kronk/plist_parser'
  require 'kronk/xml_parser'


  # Default config file to load. Defaults to ~/.kronk.
  DEFAULT_CONFIG_FILE = File.expand_path "~/.kronk"


  # Default cache file.
  DEFAULT_CACHE_FILE = File.expand_path "~/.kronk_cache"


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
    :diff_format    => :ascii_diff,
    :show_lines     => false,
    :cache_file     => DEFAULT_CACHE_FILE,
    :requires       => [],
    :uri_options    => {},
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

  def self.load_requires
    return unless config[:requires]
    config[:requires].each{|lib| require lib }
  end


  ##
  # Creates the default config file at the given path.

  def self.make_config_file filepath=DEFAULT_CONFIG_FILE
    File.open filepath, "w+" do |file|
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
  # Returns config-defined options for a given uri.
  # Returns empty Hash if none found.

  def self.options_for_uri uri
    config[:uri_options].each do |key, options|
      return options if uri == key || uri =~ %r{#{key}}
    end

    Hash.new
  end


  ##
  # Ask the user for a password from stdinthe command line.

  def self.query_password str=nil
    $stderr << "#{(str || "Password:")} "
    system "stty -echo"
    password = $stdin.gets.chomp
  ensure
    system "stty echo"
    $stderr << "\n"
    password
  end


  ##
  # Make requests, parse the responses and compare the data.
  # Query arguments may be set to the special value :cache to use the
  # last live http response retrieved.
  #
  # Supports the following options:
  # :data:: Hash/String - the data to pass to the http request
  # :query:: Hash/String - the data to append to the http request path
  # :headers:: Hash - extra headers to pass to the request
  # :http_method:: Symbol - the http method to use; defaults to :get
  # :user_agent:: String - user agent string or alias; defaults to 'kronk'
  # :auth:: Hash - must contain :username and :password; defaults to nil
  # :proxy:: Hash/String - http proxy to use; defaults to nil
  # :only_data:: String/Array - extracts the data from given data paths
  # :ignore_data:: String/Array - defines which data points to exclude
  # :with_headers:: Bool/String/Array - defines which headers to include
  # :parser:: Object - The parser to use for the body; default nil
  # :raw:: Bool - run diff on raw strings
  #
  # Returns a diff object.

  def self.compare query1, query2, options={}
    diff =
      if options[:raw]
        raw_diff query1, query2, options
      else
        data_diff query1, query2, options
      end

    diff
  end


  ##
  # Return a diff object from two responses' raw data.
  # See Kronk#compare for supported options (except :raw)

  def self.raw_diff query1, query2, options={}
    opts1 = options.merge options_for_uri(query1)
    opts2 = options.merge options_for_uri(query2)

    resp1 = Request.retrieve query1, opts1
    resp2 = Request.retrieve query2, opts2

    Diff.new resp1.selective_string(opts1), resp2.selective_string(opts2)
  end


  ##
  # Return a diff object from two parsed responses.
  # See Kronk#compare for supported options (except :raw)

  def self.data_diff query1, query2, options={}
    opts1 = options.merge options_for_uri(query1)
    opts2 = options.merge options_for_uri(query2)

    resp1 = Request.retrieve query1, opts1
    resp2 = Request.retrieve query2, opts2

    Diff.new_from_data resp1.selective_data(opts1),
                       resp2.selective_data(opts2),
                       options
  end


  ##
  # Runs the kronk command with the given terminal args.

  def self.run argv=ARGV
    begin
      load_config

    rescue Errno::ENOENT
      make_config_file

      $stderr << "\nNo config file was found.\n\n"
      $stderr << "Created default config in #{DEFAULT_CONFIG_FILE}\n"
      $stderr << "Edit file if necessary and try again.\n"
      exit 1
    end

    options = parse_args argv

    config[:requires].concat options[:requires] if options[:requires]
    load_requires

    options[:cache_response] = config[:cache_file] if config[:cache_file]

    uri1, uri2 = options.delete :uris

    if uri1 && uri2
      diff = compare uri1, uri2, options
      puts diff.formatted
      verbose "\n\nFound #{diff.count} diff(s).\n"

    elsif options[:raw]
      options = options.merge options_for_uri(uri1)

      out = Request.retrieve(uri1, options).selective_string options
      out = Diff.insert_line_nums out if config[:show_lines]
      puts out

    else
      options = options.merge options_for_uri(uri1)

      data = Request.retrieve(uri1, options).selective_data options
      out  = Diff.ordered_data_string data, options[:struct]
      out  = Diff.insert_line_nums out if config[:show_lines]
      puts out
    end

  rescue Request::NotFoundError, Response::MissingParser => e
    $stderr << "\nError: #{e.message}\n"
    exit 2
  end


  ##
  # Print string only if verbose

  def self.verbose str
    $stdout << "#{str}\n" if config[:verbose]
  end


  ##
  # Parse ARGV

  def self.parse_args argv
    options = {
      :auth           => {},
      :no_body        => false,
      :proxy          => {},
      :uris           => [],
      :with_headers   => false
    }

    options = parse_data_path_args options, argv

    opts = OptionParser.new do |opt|
      opt.program_name = File.basename $0
      opt.version = VERSION
      opt.release = nil

      opt.banner = <<-STR
Kronk runs diffs against data from live and cached http responses.

  Usage:
    #{opt.program_name} --help
    #{opt.program_name} --version
    #{opt.program_name} uri1 [uri2] [options...] [-- data-paths]

  Examples:
    #{opt.program_name} http://example.com/A
    #{opt.program_name} http://example.com/B --prev --raw
    #{opt.program_name} http://example.com/B.xml local/file/B.json
    #{opt.program_name} file1.json file2.json -- **/key1=val1 -root/key?

  Arguments after -- will be used to focus the diff on specific data points.
  If the data paths start with a '-' the matched data points will be removed.
  If the data paths start with a ":" the parent of the matched data is used.
  The ':' and '-' modifiers may be used together in that order (':-').

  Options:
      STR

      opt.on('--ascii', 'Return ascii formatted diff') do
        config[:diff_format] = :ascii_diff
      end


      opt.on('--color', 'Return color formatted diff') do
        config[:diff_format] = :color_diff
      end


      opt.on('--format STR', String,
             'Use a custom diff formatter') do |value|
        config[:diff_format] = value
      end


      opt.on('-i', '--include [header1,header2]', Array,
             'Include all or given headers in response') do |value|
        options[:with_headers] ||= []

        if value
          options[:with_headers].concat value if
            Array === options[:with_headers]
        else
          options[:with_headers] = true
        end
      end


      opt.on('-I', '--head [header1,header2]', Array,
             'Use all or given headers only in the response') do |value|
        options[:with_headers] ||= []

        if value
          options[:with_headers].concat value if
            Array === options[:with_headers]
        else
          options[:with_headers] = true
        end

        options[:no_body] = true
      end


      opt.on('--lines', 'Show line numbers') do
        config[:show_lines] = true
      end


      opt.on('--parser STR', String,
             'Override default parser') do |value|
        options[:parser] = value
      end


      opt.on('--prev', 'Use last response to diff against') do
        options[:uris].unshift :cache
      end


      opt.on('--raw', 'Run diff on the raw data returned') do
        options[:raw] = true
      end


      opt.on('-r', '--require lib1,lib2', Array,
             'Require a library or gem') do |value|
        options[:requires] ||= []
        options[:requires].concat value
      end


      opt.on('--struct', 'Run diff on the data structure') do
        options[:struct] = true
      end


      opt.on('-V', '--verbose', 'Make the operation more talkative') do
        config[:verbose] = true
      end


      opt.separator <<-STR

  HTTP Options:
      STR

      opt.on('-d', '--data STR', String,
             'Post data with the request') do |value|
        options[:data] = value
        options[:http_method] ||= 'POST'
      end


      opt.on('-H', '--header STR', String,
             'Header to pass to the server request') do |value|
        options[:headers] ||= {}

        key, value = value.split ": ", 2
        options[:headers][key] = value.strip
      end


      opt.on('-A', '--user-agent STR', String,
             'User-Agent to send to server or a valid alias') do |value|
        options[:user_agent] = value
      end


      opt.on('-L', '--location [NUM]', Integer,
             'Follow the location header always or num times') do |value|
        options[:follow_redirects] = value || true
      end


      opt.on('-?', '--query STR', String,
             'Append query to URLs') do |value|
        options[:query] = value
      end


      opt.on('--suff STR', String,
             'Add common path items to the end of each URL') do |value|
        options[:uri_suffix] = value
      end


      opt.on('-U', '--proxy-user STR', String,
             'Set proxy user and/or password: usr[:pass]') do |value|
        options[:proxy][:username], options[:proxy][:password] =
          value.split ":", 2

        options[:proxy][:password] ||= query_password "Proxy password:"
      end


      opt.on('-u', '--user STR', String,
             'Set server auth user and/or password: usr[:pass]') do |value|
        options[:auth][:username], options[:auth][:password] =
          value.split ":", 2

        options[:auth][:password] ||= query_password "Server password:"
      end


      opt.on('-X', '--request STR', String,
             'The request method to use') do |value|
        options[:http_method] = value
      end


      opt.on('-x', '--proxy STR', String,
             'Use HTTP proxy on given port: host[:port]') do |value|
        options[:proxy][:address], options[:proxy][:port] = value.split ":", 2
      end

      opt.separator nil
    end

    opts.parse! argv

    unless $stdin.tty?
      io = StringIO.new $stdin.read
      options[:uris] << io
    end

    options[:uris].concat argv
    options[:uris].slice!(2..-1)

    if options[:uris].empty?
      $stderr << "\nError: You must enter at least one URI\n\n"
      $stderr << opts.to_s
      exit 1
    end

    options
  end


  ##
  # Searches ARGV and returns data paths to add or exclude in the diff.
  # Returns the array [only_paths, except_paths]

  def self.parse_data_path_args options, argv
    return options unless argv.include? "--"

    data_paths = argv.slice! argv.index("--")..-1
    data_paths.shift

    data_paths.each do |path|
      if path[0,1] == "-"
        (options[:ignore_data] ||= []) << path[1..-1]

      elsif path[0,2] == ":-"
        (options[:ignore_data_with] ||= []) << path[2..-1]

      elsif path[0,1] == ":"
        (options[:only_data_with] ||= []) << path[1..-1]

      else
        (options[:only_data] ||= []) << path
      end
    end

    options
  end
end
