class Kronk

  ##
  # Finds specific data points from a nested Hash or Array data structure
  # through the use of a file-glob-like path selector.
  #
  # Special characters are: "/ * ? = | \ . , \ ( )"
  # and are interpreted as follows:
  #
  # :foo/ - walk down tree by one level from key "foo"
  # :*/foo - walk down tree from any parent with key "foo" as a child
  # :foo1|foo2 - return elements with key value of "foo1" or "foo2"
  # :foo(1|2) - same behavior as above
  # :foo=val - return elements where key has a value of val
  # :foo\* - return root-level element with key "foo*" ('*' char is escaped)
  # :**/foo - recursively search for key "foo"
  # :foo? - return keys that match /\Afoo.?\Z/
  # :2..10 - match any integer from 2 to 10
  # :2...10 - match any integer from 2 to 9
  # :2,5 - match any integer from 2 to 7
  #
  # Examples:
  #
  #   # Recursively look for elements with value "val" under top element "root"
  #   Path.find "root/**=val", data
  #
  #   # Find child elements of "root" that have a key of "foo" or "bar"
  #   Path.find "root/foo|bar", data
  #
  #   # Recursively find child elements of root whose value is 1, 2, or 3.
  #   Path.find "root/**=1..3", data
  #
  #   # Recursively find child elements of root of literal value "1..3"
  #   Path.find "root/**=\\1..3", data

  class Path

    # Used as path instruction to go up one path level.
    module PARENT; end

    # Mapping of letters to Regexp options.
    REGEX_OPTS = {
      "i" => Regexp::IGNORECASE,
      "m" => Regexp::MULTILINE,
      "u" => (Regexp::FIXEDENCODING if defined?(Regexp::FIXEDENCODING)),
      "x" => Regexp::EXTENDED
    }

    # The path item delimiter character "/"
    DCH = "/"

    # The replacement character "%" for path mapping
    RCH = "%"

    # The path character to assign value "="
    VCH = "="

    # The escape character to use any PATH_CHARS as its literal.
    ECH = "\\"

    # The Regexp escaped version of ECH.
    RECH = Regexp.escape ECH

    # The EndOfPath delimiter after which regex opt chars may be specified.
    EOP = DCH + DCH

    # The key string that represents PARENT.
    PARENT_KEY = ".."

    # The key string that indicates recursive lookup.
    RECUR_KEY = "**"


    ##
    # Instantiate a Path object with a String data path.
    #   Path.new "/path/**/to/*=bar/../../**/last"

    def initialize path_str, regex_opts=nil, &block
      path_str = path_str.dup
      @path = self.class.parse_path_str path_str, regex_opts, &block
    end


    ##
    # Finds the current path in the given data structure.
    # Returns a Hash of path_ary => data pairs for each match.
    #
    # If a block is given, yields the parent data object matched,
    # the key, and the path array.
    #
    #   data = {:path => {:foo => :bar, :sub => {:foo => :bar2}}, :other => nil}
    #   path = Path.new "path/**/foo"
    #
    #   all_args = []
    #
    #   path.find_in data |*args|
    #     all_args << args
    #   end
    #   #=> {[:path, :foo] => :bar, [:path, :sub, :foo] => :bar2}
    #
    #   all_args
    #   #=> [
    #   #=>  [{:foo => :bar, :sub => {:foo => :bar2}}, :foo, [:path, :foo]],
    #   #=>  [{:foo => :bar2}, :foo, [:path, :sub, :foo]]
    #   #=> ]

    def find_in data
      matches = {[] => data}

      @path.each_with_index do |matcher, i|
        last_item = i == @path.length - 1

        self.class.assign_find(matches, data, matcher) do |sdata, key, spath|
          yield sdata, key, spath if last_item && block_given?
        end
      end

      matches
    end


    ##
    # Returns a path-keyed data hash. Be careful of mixed key types in hashes
    # as Symbols and Strings both use #to_s.

    def self.pathed data, escape=true
      new_data = {}

      find "**", data do |subdata, key, path|
        next if Array === subdata[key] || Hash === subdata[key]
        path_str = "#{DCH}#{join(path, escape)}"
        new_data[path_str] = subdata[key]
      end

      new_data
    end


    ##
    # Joins an Array into a path String.

    def self.join path_arr, escape=true
      path_esc = "*?()|/."
      path_arr.map! do |k|
        k.to_s.gsub(/([#{path_esc}])/){|m| "\\#{m}"}
      end if escape

      path_arr.join(DCH)
    end


    ##
    # Fully streamed version of:
    #   Path.new(str_path).find_in data
    #
    # See Path#find_in for usage.

    def self.find path_str, data, regex_opts=nil, &block
      matches = {[] => data}

      parse_path_str path_str, regex_opts do |matcher, last_item|
        assign_find matches, data, matcher do |sdata, key, spath|
          yield sdata, key, spath if last_item && block_given?
        end
      end

      matches
    end


    ##
    # Common find functionality that assigns to the matches hash.

    def self.assign_find matches, data, matcher
      matches.keys.each do |path|
        pdata = matches.delete path

        if matcher.key == PARENT
          path    = path[0..-2]
          subdata = data_at_path path[0..-2], data

          #!! Avoid yielding parent more than once
          next if matches[path]

          yield subdata, path.last, path if block_given?
          matches[path] = subdata[path.last]
          next
        end

        matcher.find_in pdata, path do |sdata, key, spath|
          yield sdata, key, spath if block_given?
          matches[spath] = sdata[key]
        end
      end
    end


    ##
    # Returns the data object found at the given path array.
    # Returns nil if not found.

    def self.data_at_path path_arr, data
      c_data = data

      path_arr.each do |key|
        c_data = c_data[key]
      end

      c_data

    rescue NoMethodError, TypeError
       nil
    end


    ##
    # Parses a path String into an Array of arrays containing
    # matchers for key, value, and any special modifiers
    # such as recursion.
    #
    #   Path.parse_path_str "/path/**/to/*=bar/../../**/last"
    #   #=> [["path",ANY_VALUE,false],["to",ANY_VALUE,true],[/.*/,"bar",false],
    #   #    [PARENT,ANY_VALUE,false],[PARENT,ANY_VALUE,false],
    #   #    ["last",ANY_VALUE,true]]
    #
    # Note: Path.parse_path_str will slice the original path string
    # until it is empty.

    def self.parse_path_str path, regex_opts=nil
      path = path.dup
      regex_opts = parse_regex_opts! path, regex_opts

      parsed = []

      escaped   = false
      key       = ""
      value     = nil
      recur     = false
      next_item = false

      until path.empty?
        char = path.slice!(0..0)

        case char
        when DCH
          next_item = true
          char = ""

        when VCH
          value = ""
          next

        when ECH
          escaped = true
          next
        end unless escaped

        char = "#{ECH}#{char}" if escaped

        if value
          value << char
        else
          key << char
        end

        next_item = true if path.empty?

        if next_item
          next_item = false

          if key == RECUR_KEY
            key   = "*"
            recur = true
            key   = "" and next unless value || path.empty?

          elsif key == PARENT_KEY
            key = PARENT

            if recur
              key = "" and next unless value
              key = "*"
            end
          end

          unless key =~ /^\.?$/ && !value
            matcher = Matcher.new :key        => key,
                                  :value      => value,
                                  :recursive  => recur,
                                  :regex_opts => regex_opts

            parsed << matcher
            yield matcher, path.empty? if block_given?
          end

          key   = ""
          value = nil
          recur = false
        end

        escaped = false
      end

      parsed
    end


    ##
    # Parses the tail end of a path String to determine regexp matching flags.

    def self.parse_regex_opts! path, default=nil
      opts = default || 0

      return default unless
         path =~ %r{[^#{RECH}]#{EOP}[#{REGEX_OPTS.keys.join}]+\Z}

      path.slice!(%r{#{EOP}[#{REGEX_OPTS.keys.join}]+\Z}).to_s.
        each_char{|c| opts |= REGEX_OPTS[c] || 0}

      opts if opts > 0
    end
  end
end
