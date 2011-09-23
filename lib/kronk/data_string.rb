class Kronk

  ##
  # Creates ordered data string renders for diffing with character-precise
  # path information.
  #
  #   dstr = DataString.new({'a' => 'foo', 'b' => 'bar', 'c' => ["one", "two"]})
  #   # {
  #   #  "a": "foo",
  #   #  "b": "bar",
  #   #  "c": [
  #   #   "one",
  #   #   "two"
  #   #  ]
  #   # }
  #
  #   dstr.meta[dstr.index("\"a\"")]
  #   # /
  #
  #   dstr.meta[dstr.index("\"foo\"")]
  #   # /a
  #
  #   dstr.meta[dstr.index("\"two\"")]
  #   # /c/1

  class DataString < String

    TO_RUBY = proc do |type, obj|
      case type
      when :key_assign then " =>"
      when :key        then obj.inspect
      when :value      then obj.inspect
      when :struct
        (obj == true || obj == false) ? "Boolean" : obj.class
      end
    end


    TO_JSON = proc do |type, obj|
      case type
      when :key_assign then ":"
      when :key
        (Symbol === obj ? obj.inspect : obj.to_s).to_json
      when :value
        (Symbol === obj ? obj.inspect : obj).to_json
      when :struct
        ((obj == true || obj == false) ? "Boolean" : obj.class).to_json
      end
    end

    ##
    # Returns a ruby data string that is diff-able, meaning sorted by
    # Hash keys when available.

    def self.ruby data, opts={}
      new(data, opts, &TO_RUBY)
    end


    ##
    # Returns a json data string that is diff-able, meaning sorted by
    # Hash keys when available.

    def self.json data, opts={}
      new(data, opts, &TO_JSON)
    end


    attr_accessor :data, :meta, :struct_only


    ##
    # Create a new DataString that is diff-able, meaning sorted by
    # Hash keys when available.
    #
    # Options supported are:
    # :indentation:: Integer - how many spaces to indent by; default 1
    # :render_lang:: String - output to 'ruby' or 'json'; default 'json'
    # :struct:: Boolean - class names used instead of values; default nil
    #
    # If block is given, will yield the type of object to render and
    # an optional object to render. Types given are :key_assign, :key, :value,
    # or :struct. By default DataString uses the TO_JSON proc.

    def initialize data=nil, opts={}, &block
      @struct_only = opts[:struct]
      @indentation = opts[:indentation] || 1
      @meta        = []

      if String === data
        super data
        @data = nil

      else
        super ""
        data    = Kronk::Path.pathed(data) if Kronk.config[:render_paths]
        @data   = data
        block ||= Kronk.config[:render_lang].to_s == 'ruby' ? TO_RUBY : TO_JSON
      end

      render data, &block if data && block
    end


    ##
    # Turns a data set into an ordered string output for diff-ing.

    def render data, path=[], &block
      indent   = (path.length + 1) * @indentation
      pad      = " " * indent
      path_str = "/" << Path.join(path)

      case data

      when Hash
        append("{}", path_str) and return if data.empty?
        append "{\n", path_str

        sort_any(data.keys).each_with_index do |key, i|
          append "#{pad}#{ yield(:key, key) }#{ yield(:key_assign) } ", path_str

          value    = data[key]
          new_path = path.dup << key
          render value, new_path, &block

          append(",", path_str) unless i == data.length - 1
          append("\n", path_str)
        end

        append(("#{" " * (indent - @indentation)}}"), path_str)

      when Array
        append("[]", path_str) and return if data.empty?
        append "[\n", path_str

        (0...data.length).each do |key|
          append pad, path_str

          value    = data[key]
          new_path = path.dup << key
          render value, new_path, &block

          append(",", path_str) unless key == data.length - 1
          append("\n", path_str)
        end

        append(("#{" " * (indent - @indentation)}]"), path_str)

      else
        output = @struct_only ? yield(:struct, data) : yield(:value, data)
        append output.to_s, path_str
      end
    end


    ##
    # Add a string with metadata to the data string.

    def append str, metadata=nil
      @meta.concat([metadata] * str.length)
      self[self.length,str.length] = str
    end


    ##
    # Similar to String#<< but adds metadata.

    def << str
      if str.class == self.class
        @meta.concat str.meta
      else
        @meta.concat([@meta.last] * str.length)
      end
      super str
    end


    ##
    # Similar to String#[] but keeps metadata.

    def [] arg
      dstr = self.class.new super
      dstr.meta = @meta[arg]
      dstr
    end


    ##
    # Similar to String#split but keeps metadata.

    def split pattern=$;, *more
      arr      = super
      i        = 0
      interval = 0
      interval = (self.length - arr.join.length) / (arr.length - 1) if
        arr.length > 1

      arr.map do |str|
        ds = self.class.new str
        ds.meta = @meta[i,str.length]
        i += str.length + interval
        ds
      end
    end


    protected

    ##
    # Sorts an array of any combination of string, integer, or symbols.

    def sort_any arr
      i = 1
      until i >= arr.length
        j        = i-1
        val      = arr[i]
        prev_val = arr[j]

        loop do
          if smaller?(val, arr[j])
            arr[j+1] = arr[j]
            j = j - 1
            break if j < 0

          else
            break
          end
        end

        arr[j+1] = val

        i = i.next
      end

      arr
    end


    ##
    # Compares Numerics, Strings, and Symbols and returns true if the left
    # side is 'smaller' than the right side.

    def smaller? left, right
      case left
      when Numeric
        case right
        when Numeric then right > left
        else              true
        end

      when Symbol
        case right
        when Numeric then false
        when Symbol  then right.to_s > left.to_s
        else              true
        end

      when String
        case right
        when String  then right > left
        else              false
        end
      end
    end
  end
end
