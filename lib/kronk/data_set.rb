class Kronk

  ##
  # Wraps a complex data structure to provide a search-driven interface.

  class DataSet

    attr_accessor :data

    def initialize data
      @data = data
    end


    ##
    # Find specific data points from a nested hash or array data structure.
    # If a block is given, will pass it any matched parent data object,
    # key, and full path.
    #
    # Data points must be an Array or String with a glob-like format.
    # Special characters are: / * = | \ and are interpreted as follows:
    # :key/ - walk down tree by one level from key
    # :*/key - walk down tree from any parent with key as a child
    # :key1|key2 - return elements with key value of key1 or key2
    # :key=val - return elements where key has a value of val
    # :key\* - return root-level element with key "key*"
    #
    # Other examples:
    #   find_data data, root/**=invalid|
    #   # Returns an Array of grand-children key/value pairs
    #   # where the value is 'invalid' or blank

    def find_data data_path, curr_path=nil, &block
      self.class.find_data @data, data_path, curr_path, &block
    end


    ##
    # See DataSet#find_data

    def self.find_data data, data_path, curr_path=nil, &block
      curr_path ||= []

      key, value, rec, data_path = parse_data_path data_path

      yield_data_points data, key, value, rec, curr_path do |d, k, p|

        if data_path
          find_data d[k], data_path, p, &block
        else
          yield d, k, p
        end
      end
    end


    ##
    # Parses a given data point and returns an array with the following:
    # - Key to match
    # - Value to match
    # - Recursive matching
    # - New data path value

    def self.parse_data_path data_path
      data_path  = data_path.dup
      key        = nil
      value      = nil
      recursive  = false

      until key && key != "**" || value || data_path.empty? do
        value = data_path.slice!(%r{((.*?[^\\])+?/)})
        (value ||= data_path).sub!(/\/$/, '')

        data_path = nil if value == data_path

        key   = value.slice! %r{((.*?[^\\])+?=)}
        key, value = value, nil if key.nil?
        key.sub!(/\=$/, '')

        value = parse_path_item value if value

        if key =~ /^\*{2,}$/
          if data_path && !value
            key, value, rec, data_path = parse_data_path(data_path)
          else
            key = /.*/
          end

          recursive = true
        else
          key = parse_path_item key
        end
      end

      data_path = nil if data_path && data_path.empty?

      [key, value, recursive, data_path]
    end


    ##
    # Decide whether to make path item a regex or not.

    def self.parse_path_item str
      if str =~ /(^|[^\\])(\*|\?|\|)/
        str.gsub!(/(^|[^\\])(\*|\?)/, '\1.\2')
        str = /^(#{str})$/
      else
        str.gsub! "\\", ""
      end

      str
    end


    ##
    # Yield data object and key, if a specific key or value matches
    # the given data.

    def self.yield_data_points data, mkey, mvalue=nil,
                               recursive=false, path=nil, &block

      return unless Hash === data || Array === data
      path ||= []

      each_data_item data do |key, value|
        curr_path = path.dup << key

        found = match_data_item(mkey, key) &&
                match_data_item(mvalue, value)

        yield data, key, curr_path if found
        yield_data_points data[key], mkey, mvalue, true, curr_path, &block if
          recursive
      end
    end


    ##
    # Check if data key or value is a match for nested data searches.

    def self.match_data_item item1, item2
      return if !item1.nil? && (Array === item2 || Hash === item2)

      if Regexp === item1
        item2.to_s =~ item1
      elsif item1.nil?
        true
      else
        item2.to_s == item1.to_s
      end
    end


    ##
    # Universal iterator for Hash and Array objects.

    def self.each_data_item data, &block
      case data

      when Hash
        data.each(&block)

      when Array
        i = 0

        # We need to iterate through the array this way
        # in case items in it get deleted.

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
  end
end
