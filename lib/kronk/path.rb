class Kronk
  class Path

    module PARENT; end

    REGEX_OPTS = {
      "i" => Regexp::IGNORECASE,
      "m" => Regexp::MULTILINE,
      "u" => (Regexp::FIXEDENCODING if defined?(Regexp::FIXEDENCODING)),
      "x" => Regexp::EXTENDED
    }

    SUFF_CHARS = Regexp.escape "*?"
    PATH_CHARS = Regexp.escape("()|") << SUFF_CHARS


    ##
    # Instantiate a Path object with a String data path.
    #   Path.new "/path/**/to/*=bar/../../**/last"

    def initialize path_str, regex_opts=nil
      path_str = path_str.dup
      @path = self.class.parse_path_str! path_str, regex_opts
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
        args = [matches, data, mkey, mvalue, recur]

        self.class.assign_find(*args) do |sdata, key, spath|
          yield sdata, key, spath if i >= @path.length - 1 && block_given?
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
      path_str = path_str.dup
      matches = {[] => data}

      parse_path_str! path_str, regex_opts do |mkey, mvalue, recur|
        assign_find matches, data, mkey, mvalue, recur do |sdata, key, spath|
          yield sdata, key, spath if path_str.empty? && block_given?
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
          path = path[0..-2]
          matches[path] = data_at_path path, data
          yield matches[path], path.last, path if block_given?
          next
        end

        find_match pdata, mkey, mvalue, recur, path do |sdata, key, spath|
          matches[spath] = sdata[key]
          yield sdata, key, spath if block_given?
        end
      end
    end


    ##
    # Returns the data object found at the given path array.

    def self.data_at_path path_arr, data
      c_data = data

      path_arr.each do |key|
        c_data = c_data[key]
      end

      c_data
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

        i = 0

        while i < data.length do
          index = i
          old_length = data.length

          block.call index, data[index]

          adj = old_length - data.length
          adj = 0 if adj < 0

          i = i.next - adj
        end
      end
    end


    ##
    # Finds data with the given key and value matcher, optionally recursive.
    # Yields data, key and path Array when block is given.
    # Returns an Array of path arrays.
    #
    # TODO: add support for method or instance_var calls on objects in addition to :[]

    def self.find_match data, mkey, mvalue, recur=false, path=nil, &block
      return [] unless data.respond_to? :[]

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
      return if !item1.nil? && (Array === item2 || Hash === item2)

      if item1.class == item2.class
        item1 == item2

      elsif Regexp === item1
        item2.to_s =~ item1

      elsif Range === item1
        item1.include? item2.to_i

      elsif item1.nil?
        true

      else
        item2.to_s.downcase == item1.to_s.downcase
      end
    end


    ##
    # Decide whether to make path item a regex, range, array, or string.

    def self.parse_path_item str, regex_opts=nil
      case str
      when nil, /^(\?*\*+\?*)*$/
        nil

      when %r{^(\-?\d+)(\.{2,3})(\-?\d+)$}
        Range.new $1.to_i, $3.to_i, ($2 == "...")

      when %r{^(\-?\d+),(\-?\d+)$}
        Range.new $1.to_i, ($1.to_i + $2.to_i), true

      else
        if regex_opts || str =~ /(^|[^\\])([#{PATH_CHARS}])/

          # Remove extra suffix characters
          str.gsub! /\*+\?+|\?+\*+/, '*'
          str.gsub! /\*+/, '*'

          str = Regexp.escape str
          str.gsub! /\\([#{PATH_CHARS}])/, '\1\2'
          str.gsub! /(^|[^\\])([#{SUFF_CHARS}])/, '\1.\2'

          Regexp.new "\\A(#{str})\\Z", regex_opts

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
    #   Path.parse_path_str! "/path/**/to/*=bar/../../**/last"
    #   #=> [["path",nil,false],["to",nil,true],[/.*/,"bar",false],
    #   #    ["..",nil,false],["..",nil,false],["last",nil,true]]
    #
    # Note: Path.parse_path_str! will slice the original path string
    # until it is empty.

    def self.parse_path_str! path, regex_opts=nil
      parsed = []

      regex_opts = parse_regex_opts! path, regex_opts
      path.gsub! %r{/(\.?(/|$))+}, "/"  # Handle foo//bar, foo/./bar, foo/./.

      recur = false

      until path.empty?
        value   = path.slice! %r{(((^|.*)?[^\\])+?/)}
        value ||= path.dup

        path.replace "" if value == path

        value.sub!(/\/$/, '')           # Handle paths ending in /

        key = value.slice! %r{.*?(^|[^\\])=}
        key, value = value, nil if key.nil?
        key.sub!(/\=$/, '')

        value = parse_path_item value, regex_opts if value

        if key == "**"
          recur = true
          key   = "*"
          next unless value || path.empty?  # Handle  **=value

        elsif key == ".."
          key = PARENT
          next if recur                 # Handle  **/..
        end

        key = parse_path_item key, regex_opts unless key == PARENT
        parsed << [key, value, recur]
        recur = false

        yield(*parsed.last) if block_given?
      end

      parsed
    end


    ##
    # Parses the tail end of a path String to determine regexp matching flags.

    def self.parse_regex_opts! path, default=nil
      opts = default || 0

      path.slice!(%r{//[#{REGEX_OPTS.keys.join}]+\Z}).to_s.
        each_char{|c| opts |= REGEX_OPTS[c] || 0}

      opts if opts > 0
    end
  end
end
