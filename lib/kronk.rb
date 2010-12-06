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

require 'net/http'
require 'optparse'

class Kronk

  # This gem's version.
  VERSION = '1.0.0'


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


  # Default config to use.
  DEFAULT_CONFIG = {
    :content_types  => DEFAULT_CONTENT_TYPES.dup,
    :diff_format    => :ascii_diff
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

    if conf[:requires]
      requires = [*conf.delete(:requires)]
      self.config[:requires] ||= []
      requires.each{|lib| require lib }
      self.config[:requires].concat requires
    end

    self.config[:content_types].merge!(content_types) if content_types
    self.config.merge! conf
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
    consts = namespace.split "::"
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
        (content_type =~ %r{#{key}}) && value
      end

    return if parser_pair.empty?

    parser = parser_pair[0][1]
    parser = find_const parser if String === parser || Symbol === parser
    parser
  end


  ##
  # Make requests, parse the responses and compare the data.
  # If the second argument is omitted or is passed :cache, will
  # attempt to compare with the last made request. If there was no last
  # request will compare against nil.
  #
  # Supports the following options:
  # :data:: Hash/String - the data to pass to the http request
  # :headers:: Hash - extra headers to pass to the request
  # :http_method:: Symbol - the http method to use; defaults to :get
  # :ignore_data:: String/Array - defines which data points to exclude
  # :compare_headers:: Bool/String/Array - defines which headers to exclude
  # :raw:: Bool - run diff on raw strings
  #
  # Returns a diff object.

  def self.compare query1, query2=:cache, options={}
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

  def self.raw_diff query1, query2, options={}
    resp1 = Request.retrieve query1, options
    resp2 = Request.retrieve query2, options

    Diff.new resp1.selective_string(options), resp2.selective_string(options)
  end


  ##
  # Return a diff object from two parsed responses.

  def self.data_diff query1, query2, options={}
    resp1 = Request.retrieve query1, options
    resp2 = Request.retrieve query2, options

    Diff.new_from_data resp1.selective_data(options),
                       resp2.selective_data(options)
  end


  ##
  # Runs the kronk command with the given terminal args.

  def self.run argv=ARGV
    begin
      load_config

    rescue Errno::ENOENT
      make_config_file

      puts "\nNo config file was found.\n\n"
      puts "Created default config in #{DEFAULT_CONFIG_FILE}"
      puts "Edit file if necessary and try again."
      exit 1
    end

    options = parse_args argv
    uri1, uri2 = options.delete :uris

    if uri1 && uri2
      diff = compare uri1, uri2, options
      puts diff.formatted(config[:diff_format])

    elsif options[:raw]
      puts Request.retrieve(uri1).selective_string(options)

    else
      data = Request.retrieve(uri1).selective_data options
      puts Diff.ordered_data_string(data)
    end

  rescue Request::NotFoundError => e
    puts "\nError: #{e.message}"
    exit 2
  end


  ##
  # Parse ARGV

  def self.parse_args argv
    options = {
      :compare_headers => false,
      :no_body         => false,
      :uris            => []
    }

    options[:only_data], options[:ignore_data] = parse_data_path_args argv

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
    #{opt.program_name} --raw --prev http://example.com/B
    #{opt.program_name} http://example.com/B.xml local/file/B.json
    #{opt.program_name} file1.json file2.json -- **/key1=val1 -root/key?

  Arguments after -- will be used to focus the diff on specific data points.
  If the data paths start with a '-' the matched data points will be removed.

  Options:
      STR

      opt.on('-i', '--include [header1,header2]', Array,
             'Include all or given headers in response') do |value|
        options[:compare_headers] ||= []

        if value
          options[:compare_headers].concat value if
            Array === options[:compare_headers]
        else
          options[:compare_headers] = true
        end
      end

      opt.on('-I', '--head [header1,header2]', Array,
             'Use all or given headers only in the response') do |value|
        options[:compare_headers] ||= []

        if value
          options[:compare_headers].concat value if
            Array === options[:compare_headers]
        else
          options[:compare_headers] = true
        end

        options[:no_body]         = true
      end

      opt.on('-d', '--data STR', String,
             'Post data with the request') do |value|
        options[:data] = value
        options[:http_method] ||= 'POST'
      end


      opt.on('--prev', 'Use last response to diff against') do
        options[:uris] << :cache
      end

      opt.on('-H', '--header STR', String,
             'Header to pass to the server request') do |value|
        options[:headers] ||= []
        options[:headers] << value
      end

      opt.on('-L', '--location [NUM]', Integer,
             'Follow the location header always or num times') do |value|
        options[:follow_redirects] = value || true
      end

      opt.on('-X', '--request STR', String,
             'The request method to use') do |value|
        options[:http_method] = value
      end

      opt.on('-r', '--require lib1,lib2', Array,
             'Require a library or gem') do |value|
        options[:require] ||= []
        options[:require].concat value
      end

      opt.on('--raw', 'Run diff on the raw data returned') do
        options[:raw] = true
      end

      #opt.on('-v', '--verbose', 'Make the operation more talkative') do
      #  options[:verbose] = true
      #end

      opt.separator nil
    end

    opts.parse! argv

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

  def self.parse_data_path_args argv
    return unless argv.include? "--"

    data_paths = argv.slice! argv.index("--")..-1
    data_paths.shift

    only_paths   = nil
    except_paths = nil

    data_paths.each do |path|
      if path[0,1] == "-"
        (except_paths ||= []) << path[1..-1]
      else
        (only_paths ||= []) << path
      end
    end

    [only_paths, except_paths]
  end
end
