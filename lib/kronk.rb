require 'rubygems'
require 'plist'
require 'json'
require 'nokogiri'
require 'differ'

require 'net/http'


class Kronk

  # This gem's version.
  VERSION = '1.0.0'


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
    'xml'     => 'XMLParser',
    'json'    => 'JSON',
    'js'      => 'JSON',
    'plist'   => 'PlistParser'
  }


  # Default config to use.
  DEFAULT_CONFIG = {
    :content_types  => DEFAULT_CONTENT_TYPES,
    :ignore_headers => ["Date", "Age"]
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

    conf[:content_types].merge!(content_types) if content_types
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
  # Make requests, parse the responses and compare the data.
  # If the second argument is omitted or is passed :cache, will
  # attempt to compare with the last made request. If there was no last
  # request will compare against nil.
  #
  # Supports the following options:
  # :data:: Hash/String - the data to pass to the http request
  # :headers:: Hash - extra headers to pass to the request
  # :http_method:: Symbol - the http method to use; defaults to :get
  # :query:: Hash/String - data to append to url query
  # :ignore_data:: String/Array - defines which data points to exclude
  # :ignore_headers:: Bool/String/Array - defines which headers to exclude
  #
  # Returns a diff Array:
  #
  #   compare "http://host.com/test.json", :cache
  #   [[:deleted, {'foo' => 'bar'},{'foo' => 'baz'}]]

  def self.compare query1, query2=:cache, options={}
    diff = ResponseDiff.retrieve_new query1, query2, options
    diff.data_diff
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
  # :query:: Hash/String - data to append to url query
  # :ignore_headers:: Bool/String/Array - defines which headers to exclude
  #
  # Returns a diff Array:
  #
  #   diff "http://host.com/test.json", :cache
  #   ["same line 1\n", ['- "foo":"bar"\n','+ "foo":"baz"'], "same line 3\n"]

  def self.diff query1, query2=:cache, options={}
    diff = ResponseDiff.retrieve_new query1, query2, options
    diff.raw_diff
  end
end
