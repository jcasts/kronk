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

class Kronk

  # This gem's version.
  VERSION = '1.0.0'


  require 'kronk/data_set'
  require 'kronk/diff'
  require 'kronk/response'
  require 'kronk/request'
  require 'kronk/response_diff'
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
    :content_types  => DEFAULT_CONTENT_TYPES.dup
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
  # :ignore_headers:: Bool/String/Array - defines which headers to exclude
  #
  # Returns a formatted diff string:
  #
  #   compare "http://host.com/test.json", :cache
  #   "val1\n- val11\n+ val12"

  def self.compare query1, query2=:cache, options={}
    diff = ResponseDiff.retrieve_new query1, query2, options
    diff.data_diff.formatted
  end


  ##
  # Make requests, parse and compare the response strings.
  # If the second argument is omitted or is passed :cache, will
  # attempt to compare with the last made request. If there was no last
  # request will compare against empty string.
  #
  # Supports the following options:
  # :data:: Hash/String - the data to pass to the http request
  # :headers:: Hash - extra headers to pass to the request
  # :http_method:: Symbol - the http method to use; defaults to :get
  # :ignore_headers:: Bool/String/Array - defines which headers to exclude
  #
  # Returns a formatted diff string:
  #
  #   diff "http://host.com/test.json", :cache
  #   "val1\n- val11\n+ val12"

  def self.diff query1, query2=:cache, options={}
    diff = ResponseDiff.retrieve_new query1, query2, options
    diff.raw_diff.formatted
  end
end
