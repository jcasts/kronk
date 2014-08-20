require 'yaml'

class Kronk::OAuthConfig

  SELECTED_KEY = 'selected'
  ACCOUNTS_KEY = 'accounts'

  def self.load_file yaml_file
    new( YAML.load_file(yaml_file) )
  end


  def initialize config=nil
    @config = config || {}
  end


  def has_name_for_host? name, host
    !!get(name, host)
  end


  def has_host? host
    !!config_for_host(host)
  end


  def get name, host
    config = config_for_host(host)
    config && config[ACCOUNTS_KEY] && config[ACCOUNTS_KEY][name]
  end


  def set name, host, config
    @config[host] ||= {SELECTED_KEY => name, ACCOUNTS_KEY => {}}
    @config[host][ACCOUNTS_KEY][name] = config
  end


  def remove host, name=nil
    if name
      config = config_for_host(host)
      config[ACCOUNTS_KEY].delete(name)
      if config[ACCOUNTS_KEY].empty?
        @config.delete(host)
      elsif config[SELECTED_KEY] == name
        config[SELECTED_KEY] = nil
      end 

    else
      @config.delete(host)
    end
  end


  def rename host, name, new_name
    selected = active_name_for_host(host) == name
    config = get(name, host)
    remove(host, name)
    set(new_name, host, config)
    set_active_for_host(new_name, host) if selected
  end


  def get_active_for_host host
    name = active_name_for_host(host)
    return config[ACCOUNTS_KEY] && config[ACCOUNTS_KEY][name]
  end


  def set_active_for_host name, host
    config = config_for_host(host)
    return false unless config
    return false unless config[ACCOUNTS_KEY] && config[ACCOUNTS_KEY][name] || name.nil?

    config[SELECTED_KEY] = name
    return true
  end


  def active_name_for_host host
    config = config_for_host(host)
    return unless config

    return config[SELECTED_KEY]
  end


  def names_for_host host
    @config[host] && @config[host][ACCOUNTS_KEY] && @config[host][ACCOUNTS_KEY].keys || []
  end


  def hosts
    @config.keys
  end


  def config_for_host host
    @config[host]
  end


  def empty?
    @config.empty?
  end


  def save_file yaml_file
    File.open(yaml_file, "w+") {|f| f.write @config.to_yaml }
  end


  def each &block
    @config.each do |host, data|
      configs = data[ACCOUNTS_KEY]
      configs.each do |name, config|
        block.call(host, name, config)
      end
    end
  end
end