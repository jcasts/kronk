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

    # Used as path item value to match any key or value.
    module ANY_VALUE; end

    # Mapping of letters to Regexp options.
    REGEX_OPTS = {
      "i" => Regexp::IGNORECASE,
      "m" => Regexp::MULTILINE,
      "u" => (Regexp::FIXEDENCODING if defined?(Regexp::FIXEDENCODING)),
      "x" => Regexp::EXTENDED
    }

    # Shortcut characters that require modification before being turned into
    # a matcher.
    SUFF_CHARS = Regexp.escape "*?"

    # All special path characters.
    PATH_CHARS = Regexp.escape("()|") << SUFF_CHARS

    # Path chars that get regexp escaped.
    RESC_CHARS = "*?()|/"

    # The path item delimiter character "/"
    DCH = "/"

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

    # Matcher for Range path item.
    RANGE_MATCHER  = %r{^(\-?\d+)(\.{2,3})(\-?\d+)$}

    # Matcher for index,length path item.
    ILEN_MATCHER   = %r{^(\-?\d+),(\-?\d+)$}

    # Matcher allowing any value to be matched.
    ANYVAL_MATCHER = /^(\?*\*+\?*)*$/

    # Matcher to assert if any unescaped special chars are in a path item.
    PATH_CHAR_MATCHER = /(^|[^#{RECH}])([#{PATH_CHARS}])/


    ##
    # Instantiate a Path object with a String data path.
    #   Path.new "/path/**/to/*=bar/../../**/last"

    def initialize path_str, regex_opts=nil
      path_str = path_str.dup
      @path = self.class.parse_path_str path_str, regex_opts
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

      @path.each_with_index do |(mkey, mvalue, recur), i|
        args      = [matches, data, mkey, mvalue, recur]
        last_item = i == @path.length - 1

        self.class.assign_find(*args) do |sdata, key, spath|
          yield sdata, key, spath if last_item && block_given?
        end
      end

      matches
    end


    ##
    # Fully streamed version of:
    #   Path.new(str_path).find_in data
    #
    # See Path#find_in for usage.

    def self.find path_str, data, regex_opts=nil, &block
      matches = {[] => data}

      parse_path_str path_str, regex_opts do |mkey, mvalue, recur, last_item|
        assign_find matches, data, mkey, mvalue, recur do |sdata, key, spath|
          yield sdata, key, spath if last_item && block_given?
        end
      end

      matches
    end


    ##
    # Common find functionality that assigns to the matches hash.

    def self.assign_find matches, data, mkey, mvalue, recur
      matches.keys.each do |path|
        pdata = matches.delete path

        if mkey == PARENT
          path    = path[0..-2]
          subdata = data_at_path path[0..-2], data

          #!! Avoid yielding parent more than once
          next if matches[path]

          yield subdata, path.last, path if block_given?
          matches[path] = subdata[path.last]
          next
        end

        find_match pdata, mkey, mvalue, recur, path do |sdata, key, spath|
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
    # Universal iterator for Hash and Array like objects.
    # The data argument must either respond to both :each_with_index
    # and :length, or respond to :each yielding a key/value pair.

    def self.each_data_item data, &block
      if data.respond_to?(:has_key?) && data.respond_to?(:each)
        data.each(&block)

      elsif data.respond_to?(:each_with_index) && data.respond_to?(:length)
        # We need to iterate through the array this way
        # in case items in it get deleted.
        (data.length - 1).downto(0) do |i|
          block.call i, data[i]
        end
      end
    end


    ##
    # Finds data with the given key and value matcher, optionally recursive.
    # Yields data, key and path Array when block is given.
    # Returns an Array of path arrays.

    def self.find_match data, mkey, mvalue=ANY_VALUE,
                        recur=false, path=nil, &block

      return [] unless Array === data || Hash === data

      paths  = []
      path ||= []

      each_data_item data do |key, value|
        c_path = path.dup << key

        if match_data_item(mkey, key) && match_data_item(mvalue, value)
          yield data, key, c_path if block_given?
          paths << c_path
        end

        paths.concat \
          find_match(data[key], mkey, mvalue, true, c_path, &block) if recur
      end

      paths
    end


    ##
    # Check if data key or value is a match for nested data searches.

    def self.match_data_item item1, item2
      return if ANY_VALUE != item1 && (Array === item2 || Hash === item2)

      if item1.class == item2.class
        item1 == item2

      elsif Regexp === item1
        item2.to_s =~ item1

      elsif Range === item1
        item1.include? item2.to_i

      elsif ANY_VALUE == item1
        true

      else
        item2.to_s.downcase == item1.to_s.downcase
      end
    end


    ##
    # Decide whether to make path item matcher a regex, range, array, or string.

    def self.parse_path_item str, regex_opts=nil
      case str
      when nil, ANYVAL_MATCHER
        ANY_VALUE

      when RANGE_MATCHER
        Range.new $1.to_i, $3.to_i, ($2 == "...")

      when ILEN_MATCHER
        Range.new $1.to_i, ($1.to_i + $2.to_i), true

      else
        if String === str && (regex_opts || str =~ PATH_CHAR_MATCHER)

          # Remove extra suffix characters
          str.gsub! %r{(^|[^#{RECH}])(\*+\?+|\?+\*+)}, '\1*'
          str.gsub! %r{(^|[^#{RECH}])\*+}, '\1*'

          str = Regexp.escape str

          # Remove escaping from special path characters
          str.gsub! %r{#{RECH}([#{PATH_CHARS}])}, '\1'
          str.gsub! %r{#{RECH}([#{RESC_CHARS}])}, '\1'
          str.gsub! %r{(^|[^#{RECH}])([#{SUFF_CHARS}])}, '\1.\2'

          Regexp.new "\\A(#{str})\\Z", regex_opts

        elsif String === str
          str.gsub %r{#{RECH}([^#{RECH}]|$)}, '\1'

        else
          str
        end
      end
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
            parsed << [ parse_path_item(key, regex_opts),
                        parse_path_item(value, regex_opts),
                        recur ]

            yield_args = (parsed.last.dup << path.empty?)

            yield(*yield_args) if block_given?
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
