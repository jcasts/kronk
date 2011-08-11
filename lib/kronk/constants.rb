class Kronk

  # Generic Request exception.
  class Exception < ::Exception; end

  # Raised when the URI was not resolvable.
  class NotFoundError < Exception; end

  # Raised when HTTP times out.
  class TimeoutError < Exception; end

  # Raised when a missing (but non-mandatory) dependency can't be loaded.
  class MissingDependency < Exception; end


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


  # Recursive Hash merge proc.
  DEEP_MERGE =
    proc do |key,v1,v2|
      Hash === v1 && Hash === v2 ? v1.merge(v2,&DEEP_MERGE) : v2
    end


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
    :indentation    => 1,
    :requires       => [],
    :show_lines     => false,
    :uri_options    => {},
    :use_cookies    => true,
    :user_agents    => USER_AGENTS.dup
  }
end
