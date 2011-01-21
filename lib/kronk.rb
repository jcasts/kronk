require 'rubygems'

require 'json'
require 'cookiejar'
require 'rack'

require 'net/https'
require 'optparse'
require 'yaml'

class Kronk

  # This gem's version.
  VERSION = '1.2.0'


  ##
  # Returns true if kronk is running on ruby for windows.

  def self.windows?
    !!(RUBY_PLATFORM.downcase =~ /mswin|mingw|cygwin/)
  end


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


  # Default cookies file.
  DEFAULT_COOKIES_FILE = File.expand_path "~/.kronk_cookies"


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
    :cookies_file   => DEFAULT_COOKIES_FILE,
    :use_cookies    => true,
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

  def self.load_requires more_requires=nil
    return unless config[:requires] || more_requires
    (config[:requires] | more_requires.to_a).each{|lib| require lib }
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
  # Returns merged config-defined options for a given uri.
  # Values in cmd_opts take precedence.
  # Returns cmd_opts Hash if none found.

  def self.merge_options_for_uri uri, cmd_opts={}
    out_opts = Hash.new.merge cmd_opts

    config[:uri_options].each do |matcher, options|
      next unless (uri == matcher || uri =~ %r{#{matcher}}) && Hash === options

      options.each do |key, val|
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
        verbose "Warning: No parser for #{resp['Content-Type']} [#{uri}]"
        resp.selective_string options
      end
    end
  end



  ##
  # Start an IRB console with the given response object.

  def self.irb resp
    require 'irb'

    $http_response = resp
    $response = resp.parsed_body rescue resp.body

    puts "\nHTTP Response is in $http_response"
    puts "Response data is in $response\n\n"

    IRB.start
    exit 1
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
      exit 2
    end

    load_cookie_jar

    options = parse_args argv

    load_requires options[:requires]

    at_exit do
      save_cookie_jar
    end

    options[:cache_response] = config[:cache_file] if config[:cache_file]

    uri1, uri2 = options.delete :uris

    if uri1 && uri2
      diff = compare uri1, uri2, options
      puts "#{diff.formatted}\n" unless config[:brief]

      if config[:verbose] || config[:brief]
        $stdout << "Found #{diff.count} diff(s).\n"
      end

      exit 1 if diff.count > 0

    else
      out = retrieve_data_string uri1, options
      out = Diff.insert_line_nums out if config[:show_lines]
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


      opt.on('--config STR', String,
             'Load the given Kronk config file') do |value|
        load_config value
      end


      opt.on('-q', '--brief', 'Output only whether URI responses differ') do
        config[:brief] = true
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


      opt.on('--irb', 'Start an IRB console') do
        options[:irb] = true
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

      opt.on('--clear-cookies', 'Delete all saved cookies') do
        clear_cookies!
      end


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


      opt.on('--no-cookies', 'Don\'t use cookies for this session') do
        options[:no_cookies] = true
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

    argv.clear

    raise OptionParser::MissingArgument, "You must enter at least one URI" if
      options[:uris].empty?

    options

  rescue => e
    $stderr << "\nError: #{e.message}\n"
    $stderr << "See 'kronk --help' for usage\n\n"
    exit 1
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
