class Kronk

  ##
  # Command line interface.

  class Cmd

    ##
    # Saves the raw http response to a cache file.

    def self.cache_response resp, filepath=nil
      filepath ||= Kronk.config[:cache_file]
      return unless filepath

      begin
        File.open(filepath, "wb+") do |file|
          file.write resp.raw
        end
      rescue => e
        error "#{e.class}: #{e.message}"
      end
    end


    ##
    # Start an IRB console with the given Kronk::Response object.

    def self.irb resp
      require 'irb'

      $http_response = resp
      $response = begin
                    resp.parsed_body
                  rescue Response::MissingParser
                    resp.body
                  end

      $stdout.puts "\nHTTP Response is in $http_response"
      $stdout.puts "Response data is in $response\n\n"

      IRB.start
      false
    end


    ##
    # Try to load the config file. If not found, create the default one
    # and exit.

    def self.load_config_file
      Kronk.load_config

    rescue Errno::ENOENT
      make_config_file
      error "No config file was found.\n" +
            "Created default config in #{DEFAULT_CONFIG_FILE}\n" +
            "Edit file if necessary and try again.\n"
      exit 2
    end


    ##
    # Load the config-based requires.

    def self.load_requires more_requires=nil
      return unless Kronk.config[:requires] || more_requires
      (Kronk.config[:requires] | more_requires.to_a).each{|lib| require lib }
    end


    ##
    # Creates the default config file at the given path.

    def self.make_config_file
      Dir.mkdir Kronk::CONFIG_DIR unless File.directory? Kronk::CONFIG_DIR

      File.open Kronk::DEFAULT_CONFIG_FILE, "w+" do |file|
        file << Kronk::DEFAULT_CONFIG.to_yaml
      end
    end


    ##
    # Parse ARGV into options and Kronk config.

    def self.parse_args argv
      options = {
        :auth         => {},
        :no_body      => false,
        :player       => {},
        :proxy        => {},
        :uris         => [],
        :show_headers => false
      }

      options = parse_data_path_args options, argv

      opts = OptionParser.new do |opt|
        opt.program_name = File.basename $0
        opt.version = Kronk::VERSION
        opt.release = nil

        opt.banner = <<-STR

#{opt.program_name} #{opt.version}

Parse and run diffs against data from live and cached http responses.

  Usage:
    #{opt.program_name} --help
    #{opt.program_name} --version
    #{opt.program_name} uri1 [uri2] [options] [-- data-paths]

  Examples:
    #{opt.program_name} http://example.com/A
    #{opt.program_name} http://example.com/B --prev --raw
    #{opt.program_name} http://example.com/B.xml local/file/B.json
    #{opt.program_name} file1.json file2.json -- **/key1=val1 -root/key?

  Arguments after -- will be used to focus the diff on specific data points.
  If the data paths start with a '-' the matched data points will be removed.

  Options:
        STR

        opt.on('--ascii', 'Return ascii formatted diff') do
          Kronk.config[:diff_format] = :ascii_diff
        end


        opt.on('--color', 'Return color formatted diff') do
          Kronk.config[:diff_format] = :color_diff
        end


        opt.on('--completion', 'Print bash completion file path and exit') do
          file = File.join(File.dirname(__FILE__),
                    "../../script/kronk_completion")

          $stdout.puts File.expand_path(file)
          exit 2
        end


        opt.on('--config STR', String,
               'Load the given Kronk config file') do |value|
          Kronk.load_config value
        end


        opt.on('--context [NUM]', Integer,
               'Show NUM context lines for diff') do |value|
          options[:context] = value || Kronk.config[:context] || 3
        end


        opt.on('-q', '--brief', 'Output only whether URI responses differ') do
          Kronk.config[:brief] = true
        end


        opt.on('--format STR', String,
               'Use a custom diff formatter') do |value|
          Kronk.config[:diff_format] = value
        end


        opt.on('--full', 'Show the full diff') do
          options[:context] = false
        end


        opt.on('-i', '--include [HEADER1,HEADER2]', Array,
               'Include all or given headers in response') do |value|
          options[:show_headers] ||= []

          if value
            options[:show_headers].concat value if
              Array === options[:show_headers]
          else
            options[:show_headers] = true
          end

          options[:no_body] = false
        end


        opt.on('-I', '--head [HEADER1,HEADER2]', Array,
               'Use all or given headers only in the response') do |value|
          options[:show_headers] ||= []

          if value
            options[:show_headers].concat value if
              Array === options[:show_headers]
          else
            options[:show_headers] = true
          end

          options[:no_body] = true
        end


        opt.on('--indicies', 'Show modified array original indicies') do
          options[:keep_indicies] = true
        end


        opt.on('--irb', 'Start an IRB console with the response') do
          options[:irb] = true
        end


        opt.on('-l', '--lines', 'Show line numbers') do
          Kronk.config[:show_lines] = true
        end


        opt.on('--no-opts', 'Turn off config URI options') do
          Kronk.config[:no_uri_options] = true
        end


        opt.on('-P', '--parser STR', String,
               'Override default response body parser') do |value|
          options[:parser] = value
        end


        opt.on('--paths', 'Render data as path value pairs') do
          Kronk.config[:render_paths] = true
        end


        opt.on('--prev', 'Use last response to diff against') do
          options[:uris].unshift Kronk.config[:cache_file]
        end


        opt.on('-R', '--raw', 'Run diff on the raw data returned') do
          options[:raw] = true
        end


        opt.on('-r', '--require LIB1,LIB2', Array,
               'Require a library or gem') do |value|
          options[:requires] ||= []
          options[:requires].concat value
        end


        opt.on('--ruby', 'Use legacy Ruby renderer') do
          Kronk.config[:render_lang] = 'ruby'
        end


        opt.on('--struct', 'Run diff on the data structure') do
          options[:struct] = true
        end


        opt.on('-V', '--verbose', 'Make the operation more talkative') do
          Kronk.config[:verbose] = true
        end


        opt.separator <<-STR

  Player Options:
        STR

        opt.on('-c', '--concurrency NUM', Integer,
               'Number of concurrent requests to make; default: 1') do |num|
          options[:player][:concurrency] = num
        end


        opt.on('-n', '--number NUM', Integer,
               'Total number of requests to make') do |num|
          options[:player][:number] = num
        end


        opt.on('-o', '--replay-out [FORMAT]',
               'Output format used by --replay; default: stream') do |output|
          options[:player][:output] = output || :stream
        end


        opt.on('-p', '--replay [FILE]',
                'Replay the given file or STDIN against URIs') do |file|
          options[:player][:io]   = File.open(file, "r") if file
          options[:player][:io] ||= $stdin if !$stdin.tty?
          options[:player][:output] ||= :suite
        end


        opt.on('--benchmark [FILE]', 'Same as -p [FILE] -o benchmark') do |file|
          options[:player][:io]   = File.open(file, "r") if file
          options[:player][:io] ||= $stdin if !$stdin.tty?
          options[:player][:output] = :benchmark
        end


        opt.on('--stream [FILE]', 'Same as -p [FILE] -o stream') do |file|
          options[:player][:io]   = File.open(file, "r") if file
          options[:player][:io] ||= $stdin if !$stdin.tty?
          options[:player][:output] = :stream
        end


        opt.separator <<-STR

  HTTP Options:
        STR

        opt.on('--clear-cookies', 'Delete all saved cookies') do
          Kronk.clear_cookies!
        end


        opt.on('-d', '--data STR', String,
               'Post data with the request') do |value|
          options[:data] = value
          options[:http_method] ||= 'POST'
        end


        opt.on('-H', '--header STR', String,
               'Header to pass to the server request') do |value|
          options[:headers] ||= {}

          key, value = value.split(/:\s*/, 2)
          options[:headers][key] = value.to_s.strip
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


        opt.on('-t', '--timeout INT', Integer,
               'Timeout for http connection in seconds') do |value|
          Kronk.config[:timeout] = value
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
          options[:proxy][:host], options[:proxy][:port] = value.split ":", 2
        end

        opt.separator nil
      end

      opts.parse! argv

      unless options[:player].empty?
        options[:player] = Player.new options[:player]
        set_player_backend
      else
        options.delete :player
      end

      if !$stdin.tty? && !(options[:player] && options[:player].input.io)
        io = $stdin
        io = StringIO.new $stdin.read
        options[:uris] << io
      end

      options[:uris].concat argv
      options[:uris].slice!(2..-1)

      if options[:uris].empty? && File.file?(Kronk.config[:cache_file]) &&
       options[:player].nil?
        verbose "No URI specified - using kronk cache"
        options[:uris] << Kronk.config[:cache_file]
      end

      argv.clear

      raise "You must enter at least one URI" if options[:uris].empty? &&
                                                  options[:player].nil?

      options

    rescue => e
      error e.message, e.backtrace
      $stderr.puts "See 'kronk --help' for usage\n\n"
      exit 2
    end


    ##
    # Searches ARGV and returns data paths to add or exclude in the diff.
    # Returns the array [only_paths, except_paths]

    def self.parse_data_path_args options, argv
      path_index = argv.index("--")
      return options unless path_index && path_index < argv.length - 1

      data_paths = argv.slice! path_index..-1
      data_paths.shift

      options[:transform] = []

      data_paths.each do |path|
        action, path = process_path path

        # Merge identical actions into the same transaction action
        if options[:transform][-1] && options[:transform][-1][0] == action
          options[:transform][-1][1] << path

        # Merge successive maps and selects together
        elsif options[:transform][-1] &&
          [options[:transform][-1][0], action, :map, :select].uniq.length == 2
          options[:transform][-1][0] = :map
          options[:transform][-1][1] << path

        else
          options[:transform] << [action, [path]]
        end
      end

      options
    end


    ##
    # Determine the cmd-given path's action and Kronk::Path representation.

    def self.process_path path
      case path
      when /^-/
        [:delete, path[1..-1]]
      when /([^\\]>>)/
        index = path.index $1
        [:move, [path[0..index], path[index+3..-1]]]
      when /([^\\]>)/
        index = path.index $1
        [:map, [path[0..index], path[index+2..-1]]]
      else
        [:select, path]
      end
    end


    ##
    # Ask the user for a password from stdin the command line.

    def self.query_password str=nil
      $stderr << "#{(str || "Password:")} "
      system "stty -echo" unless windows?
      password = $stdin.gets.chomp
    ensure
      system "stty echo" unless windows?
      $stderr << "\n"
      password
    end


    ##
    # Runs the kronk command with the given terminal args.

    def self.run argv=ARGV
      load_config_file

      Kronk.load_cookie_jar

      options = parse_args argv
      load_requires options.delete(:requires)

      set_exit_behavior

      uri1, uri2 = options.delete :uris
      runner     = options.delete(:player) || self

      success =
        if uri1 && uri2
          runner.compare uri1, uri2, options
        else
          runner.request uri1, options
        end

      exit 1 unless success

    rescue Kronk::Exception, Errno::ECONNRESET => e
      error e.message, e.backtrace
      exit 2
    end


    ##
    # Performs a Kronk compare and renders it to $stdout.

    def self.compare uri1, uri2, options={}
      kronk = Kronk.new options
      kronk.compare uri1, uri2
      render kronk, options
    end


    ##
    # Performs a single Kronk request and renders it to $stdout.

    def self.request uri, options={}
      kronk = Kronk.new options
      kronk.request uri
      render kronk, options
    end


    ##
    # Renders the results of a Kronk compare or request
    # to $stdout.

    def self.render kronk, options={}
      cache_response kronk.response

      if options[:irb]
        irb kronk.response

      elsif kronk.diff
        render_diff kronk.diff

      elsif kronk.response
        render_response kronk.response, kronk.options
      end
    end


    ##
    # Renders a Diff instance to $stdout

    def self.render_diff diff
      $stdout.puts diff.formatted unless Kronk.config[:brief]

      if Kronk.config[:verbose] || Kronk.config[:brief]
        $stdout.puts "Found #{diff.count} diff(s)."
      end

      diff.count == 0
    end


    ##
    # Output a Kronk::Response instance. Returns true if response code
    # is in the 200 range.

    def self.render_response response, options={}
      str = response.stringify options
      str = Diff.insert_line_nums str if Kronk.config[:show_lines]
      $stdout.puts str

      verbose "\nResp. Time: #{response.time.to_f}"

      response.success?
    end


    ##
    # Set Player async state based on Kronk config.

    def self.set_player_backend
      case Kronk.config[:async]
      when 'auto', :auto, nil
        Kronk::Player.async = defined?(EM::HttpRequest)

      when true
        unless defined?(EM::HttpRequest)
          raise Kronk::Exception, "Async mode requires the em-http-request gem"
        end
        Kronk::Player.async = true

      else
        Kronk::Player.async = false
      end
    end


    ##
    # Assign at_exit and trap :INT behavior.

    def self.set_exit_behavior
      at_exit do
        Kronk.save_cookie_jar
        Kronk.save_history
      end

      trap 'INT' do
        exit 2
      end
    end


    ##
    # Print and error string

    def self.error str, more=nil
      $stderr.puts "\nError: #{str}"
      $stderr.puts more if Kronk.config[:verbose] && more
    end


    ##
    # Print string only if verbose

    def self.verbose str
      $stdout << "#{str}\n" if Kronk.config[:verbose]
    end


    ##
    # Write a warning to stderr.

    def self.warn str
      $stderr << "Warning: #{str}\n"
    end


    ##
    # Returns true if kronk is running on ruby for windows.

    def self.windows?
      $RUBY_PLATFORM ||= RUBY_PLATFORM
      !!($RUBY_PLATFORM.downcase =~ /mswin|mingw|cygwin/)
    end
  end
end
