require 'kronk/cmd'
require 'yaml'

class Kronk::Cmd::OAuth

  TWITTER_HOST = 'api.twitter.com'

  ##
  # Parse ARGV into options and Kronk config.

  def self.parse_args argv
    options = {}

    opts = OptionParser.new do |opt|
      opt.program_name = File.basename $0
      opt.version = Kronk::VERSION
      opt.release = nil

      opt.banner = <<-STR

  #{opt.program_name} #{opt.version}

  Manage OAuth configs for kronk.

    Usage:
      #{opt.program_name} --help
      #{opt.program_name} --version
      #{opt.program_name} [options]

    Examples:
      #{opt.program_name} --list
      #{opt.program_name} --list api.twitter.com
      #{opt.program_name} --add api.twitter.com
      #{opt.program_name} --remove my-config-name@api.twitter.com

      Option targets may be a in the form of a host or user@host.

    Options:
          STR

      opt.on('-l', '--list [TARGET]', 'List OAuth configs for an optional target') do |target|
        return :list_config, *parse_target(target)
      end

      opt.on('-a', '--add TARGET', 'Add a new OAuth config for a given target') do |target|
        return :add_config, *parse_target(target)
      end

      opt.on('-r', '--remove TARGET', 'Remove an OAuth config for a given target') do |target|
        return :remove_config, *parse_target(target)
      end

      opt.on('-s', '--select TARGET', 'Set default OAuth config for a given target') do |target|
        return :select_config, *parse_target(target)
      end

      opt.on('-d', '--disable HOST', 'Stop using OAuth config for a given host') do |host|
        return :disable_config, host
      end

      opt.on('-n', '--rename TARGET', 'Rename an OAuth config for a given host') do |target|
        return :rename_config, *parse_target(target)
      end

      opt.on('--twurl [FILE]', 'Import twurl configs') do |file|
        return :import_twurl, file
      end

      opt.on('-h', '--help', 'Print this help screen') do
        puts opt
        exit
      end

      opt.on('-v', '--version', 'Output Kronk version and exit') do
        puts Kronk::VERSION
        exit
      end

      opt.separator nil
    end

    opts.parse! argv

    puts opts.to_s
    exit 0

  rescue OptionParser::ParseError => e
    $stderr.puts("\nError: #{e.message}")
    $stderr.puts("See 'kronk-oauth --help' for usage\n\n")
    exit 1
  end


  def self.parse_target target
    return unless target
    target.split("@", 2).reverse
  end


	def self.run argv=ARGV
    trap 'INT' do
      puts "\n"
      exit 2
    end

    new(Kronk::DEFAULT_OAUTH_FILE).send(*parse_args(argv))
	end


  attr_accessor :file

  def initialize file
    @file = file
    @config = File.file?(@file) ? Kronk::OAuthConfig.load_file( @file ) : Kronk::OAuthConfig.new
  end


  def save_file!
    @config.save_file(@file)

    autocomplete = []
    @config.each do |host, name, config|
      autocomplete << "#{name}@#{host}"
    end

    autocomplete.concat(@config.hosts)

    File.open(Kronk::DEFAULT_OAUTH_LIST_FILE, "w+") {|f| f.write( autocomplete.join("\n") << "\n" ) }
  end


  def assert_has_name_for_host! name, host
    if !@config.has_name_for_host?(name, host)
      $stderr.puts("No config for #{name}@#{host}")
      exit 1
    end
  end


  def assert_has_host! host
    if !@config.has_host?(host)
      $stderr.puts("No config for host #{host}")
      exit 1
    end
  end


  def validate_name name, host
    while @config.has_name_for_host?(name, host)
      confirm = query("Override existing #{name}@#{host}? (y/n) ", true) == 'y'
      break if confirm
      name = query_name(host)
    end

    return name
  end


  def query_name host
    return query("Config name for #{host}: ")
  end


  def query prompt, allow_blank=false
    $stderr << prompt
    value = $stdin.gets.chomp
    return value.empty? && !allow_blank ? query(prompt) : value
  end


  def select_name host, allow_all=false
    names = @config.names_for_host(host).sort
    names.each_with_index do |name, i|
      mark = name == @config.active_name_for_host(host) ? "* " : "  "
      $stderr.puts("#{i+1}) #{mark}#{name}")
    end
    $stderr.puts("#{names.length+1})   All") if allow_all

    num = 0
    len = names.length + (allow_all ? 1 : 0)
    until num > 0 && num <= len
      num = query("Enter number: ").to_i
    end

    return names[num-1]
  end


  def add_config host, name=nil
    name ||= query_name(host)
    name = validate_name(name, host)

    config = {
      'consumer_key'    => query("Consumer Key: "),
      'consumer_secret' => query("Consumer Secret: "),
      'token'           => query("Token: "),
      'token_secret'    => query("Token Secret: ")
    }

    @config.set(name, host, config)

    save_file!

    $stderr.puts("Added config for #{name}@#{host}")
  end


  def remove_config host, name=nil
    assert_has_host!(host)
    name ||= select_name(host, true)

    @config.remove(host, name)

    save_file!

    $stderr.puts("Removed config #{name && "#{name}@"}#{host}")
  end


  def list_config host=nil, name=nil
    if host && name
      assert_has_name_for_host!(name, host)
      $stdout.puts(@config.get(name, host).to_yaml)

    elsif host
      assert_has_host!(host)
      $stdout.puts(host)
      @config.names_for_host(host).sort.each do |config_name|
        mark = config_name == @config.active_name_for_host(host) ? "* " : "  "
        $stdout.puts "  #{mark}#{config_name}\n"
      end
      $stdout.puts("\n")

    elsif @config.empty?
      $stderr.puts("No config to display")

    else
      @config.hosts.sort.each do |h|
        $stdout.puts(h)
        @config.names_for_host(h).sort.each do |config_name|
          mark = config_name == @config.active_name_for_host(h) ? "* " : "  "
          $stdout.puts "  #{mark}#{config_name}\n"
        end
        $stdout.puts("\n")
      end
    end
  end


  def select_config host, name=nil
    assert_has_host!(host)
    assert_has_name_for_host!(name, host) if name
    name ||= select_name(host)

    @config.set_active_for_host(name, host)
    save_file!

    $stderr.puts("Set active config #{name}@#{host}")
  end


  def disable_config host
    assert_has_host!(host)
    name = @config.active_name_for_host(host)

    if !name
      $stderr.puts("No active account for #{host}")
      exit 0
    end

    @config.set_active_for_host(nil, host)
    save_file!

    $stderr.puts("Disabled config #{name}@#{host}")
  end


  def rename_config host, name=nil
    assert_has_host!(host)
    name ||= select_name(host)

    new_name = query("Enter new name: ")

    @config.rename(host, name, new_name)

    save_file!

    $stderr.puts("Renamed #{name}@#{host} to #{new_name}@#{host}")
  end


  def import_twurl file=nil
    file ||= File.expand_path('~/.twurlrc')

    if !File.file?( file )
      $stderr.puts("Could not find file: #{file}")
      exit 1
    end

    config = YAML.load_file(file) rescue nil

    is_valid = Hash === config &&
                config['profiles'] &&
                Hash === config['profiles']

    unless is_valid
      $stderr.puts("Invalid file format: #{file}")
      exit 1
    end

    host = 'api.twitter.com'
    profiles = config['profiles']

    profiles.each do |name, consumers|
      name = "#{name}-twurl" if @config.has_name_for_host?(name, TWITTER_HOST)
      if consumers.length == 1
        add_twurl_config(name, consumers[consumers.keys.first])
      else
        consumers.each do |key, config|
          add_twurl_config("#{name}-#{key}", config)
        end
      end
    end

    save_file!

    $stderr.puts("Successfully imported twurl config")
  end


  def add_twurl_config name, config
    config.delete('username')
    config['token_secret'] = config.delete('secret')

    @config.set(name, TWITTER_HOST, config)
  end
end