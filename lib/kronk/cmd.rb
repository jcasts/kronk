class Kronk

  ##
  # Command line interface.

  class Cmd

    ##
    # Start an IRB console with the given http response object.

    def self.irb resp
      require 'irb'

      $http_response = resp
      $response = begin
                    resp.parsed_body
                  rescue Response::MissingParser
                    resp.body
                  end

      puts "\nHTTP Response is in $http_response"
      puts "Response data is in $response\n\n"

      IRB.start
      exit 1
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
    # Moves the old config file to the new directory structure.

    def self.move_config_file
      require 'fileutils'

      kronk_tmp_config = ".kronk.tmp"
      File.rename Kronk::CONFIG_DIR, kronk_tmp_config

      Dir.mkdir Kronk::CONFIG_DIR

      FileUtils.mv kronk_tmp_config, Kronk::DEFAULT_CONFIG_FILE
    end


    ##
    # Parse ARGV

    def self.parse_args argv
      options = {
        :auth         => {},
        :no_body      => false,
        :proxy        => {},
        :uris         => [],
        :with_headers => false
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
    #{opt.program_name} uri1 [uri2] [options...] [-- data-paths]

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
          file = File.join(File.dirname(__FILE__), "../script/kronk_completion")
          puts File.expand_path(file)
          exit 2
        end


        opt.on('--config STR', String,
               'Load the given Kronk config file') do |value|
          Kronk.load_config value
        end


        opt.on('-q', '--brief', 'Output only whether URI responses differ') do
          Kronk.config[:brief] = true
        end


        opt.on('--format STR', String,
               'Use a custom diff formatter') do |value|
          Kronk.config[:diff_format] = value
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


        opt.on('--indicies', 'Show modified array original indicies') do
          options[:keep_indicies] = true
        end


        opt.on('--irb', 'Start an IRB console') do
          options[:irb] = true
        end


        opt.on('-l', '--lines', 'Show line numbers') do
          Kronk.config[:show_lines] = true
        end


        opt.on('--no-opts', 'Turn off config URI options') do
          Kronk.config[:no_uri_options] = true
        end


        opt.on('-P', '--parser STR', String,
               'Override default parser') do |value|
          options[:parser] = value
        end


        opt.on('--prev', 'Use last response to diff against') do
          options[:uris].unshift Kronk.config[:cache_file]
        end


        opt.on('-R', '--raw', 'Run diff on the raw data returned') do
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
          Kronk.config[:verbose] = true
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


        opt.on('--timeout INT', Integer,
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

      if options[:uris].empty? && File.file?(Kronk.config[:cache_file])
        verbose "No URI specified - using kronk cache"
        options[:uris] << Kronk.config[:cache_file]
      end

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


    ##
    # Ask the user for a password from stdin the command line.

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
    # Runs the kronk command with the given terminal args.

    def self.run argv=ARGV
      begin
        Kronk.load_config

      rescue Errno::ENOENT
        make_config_file

        $stderr << "\nNo config file was found.\n"
        $stderr << "Created default config in #{DEFAULT_CONFIG_FILE}\n"
        $stderr << "Edit file if necessary and try again.\n"
        exit 2

      rescue Errno::ENOTDIR
        move_config_file

        $stderr << "\nOld config file was moved to #{DEFAULT_CONFIG_FILE}\n"
        $stderr << "Edit file if necessary and try again.\n"
        exit 2
      end

      options = parse_args argv

      Kronk.load_cookie_jar

      load_requires options[:requires]

      at_exit do
        Kronk.save_cookie_jar
        Kronk.save_history
      end

      trap 'INT' do
        exit 2
      end


      options[:cache_response] =
        Kronk.config[:cache_file] if Kronk.config[:cache_file]

      uri1, uri2 = options.delete :uris

      if uri1 && uri2
        diff = Kronk.compare uri1, uri2, options

        puts "#{diff.formatted}\n" unless Kronk.config[:brief]

        if Kronk.config[:verbose] || Kronk.config[:brief]
          $stdout << "Found #{diff.count} diff(s).\n"
        end

        exit 1 if diff.count > 0

      else
        out = Kronk.retrieve_data_string uri1, options
        out = Diff.insert_line_nums out if Kronk.config[:show_lines]
        puts out
      end

    rescue Request::Exception, Response::MissingParser, Errno::ECONNRESET => e
      $stderr << "\nError: #{e.message}\n"
      exit 2
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
      !!(RUBY_PLATFORM.downcase =~ /mswin|mingw|cygwin/)
    end
  end
end
