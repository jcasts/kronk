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
  #   # []
  #
  #   dstr.meta[dstr.index("\"foo\"")]
  #   # ['a']
  #
  #   dstr.meta[dstr.index("\"two\"")]
  #   # ['c', 1]

  class DataString < String

    TO_RUBY = proc do |type, obj|
      case type
      when :key_assign then " => "
      when :key        then obj.inspect
      when :value      then obj.inspect
      when :struct
        (obj == true || obj == false) ? "Boolean" : obj.class
      end
    end


    TO_JSON = proc do |type, obj|
      case type
      when :key_assign then ": "
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


    attr_accessor :color, :data, :meta, :struct_only


    ##
    # Create a new DataString that is diff-able, meaning sorted by
    # Hash keys when available.
    #
    # Options supported are:
    # :indentation:: Integer - how many spaces to indent by; default 1
    # :render_lang:: String - output to 'ruby' or 'json'; default 'json'
    # :struct:: Boolean - class names used instead of values; default nil
    # :color:: Boolean - render values with ANSI colors; default false
    #
    # If block is given, will yield the type of object to render and
    # an optional object to render. Types given are :key_assign, :key, :value,
    # or :struct. By default DataString uses the TO_JSON proc.

    def initialize data=nil, opts={}, &block
      @struct_only = opts[:struct]
      @color       = opts[:color]       || Kronk.config[:color_data]
      @indentation = opts[:indentation] || Kronk.config[:indentation] || 1
      @meta        = []

      if String === data
        super data
        @data = nil

      else
        super ""
        data    = Path.pathed(data) if Kronk.config[:render_paths]
        @data   = data
        block ||= Kronk.config[:render_lang].to_s == 'ruby' ? TO_RUBY : TO_JSON
      end

      render data, &block if data && block
    end


    ##
    # Assign ANSI colors based on data type.

    def colorize string, data
      case data
      when String
        "\033[0;36m#{string}\033[0m"
      when Numeric
        "\033[0;33m#{string}\033[0m"
      when TrueClass, FalseClass
        "\033[1;35m#{string}\033[0m"
      when NilClass
        "\033[1;31m#{string}\033[0m"
      else
        string
      end
    end


    ##
    # Turns a data set into an ordered string output for diff-ing.

    def render data, path=[], &block
      indent   = (path.length + 1) * @indentation
      pad      = " " * indent

      case data

      when Hash
        append("{}", path) and return if data.empty?
        append "{\n", path

        sort_any(data.keys).each_with_index do |key, i|
          append "#{pad}#{ yield(:key, key) }#{ yield(:key_assign) }", path

          value    = data[key]
          new_path = path.dup << key
          render value, new_path, &block

          append(",", path) unless i == data.length - 1
          append("\n", path)
        end

        append(("#{" " * (indent - @indentation)}}"), path)

      when Array
        append("[]", path) and return if data.empty?
        append "[\n", path

        (0...data.length).each do |key|
          append pad, path

          value    = data[key]
          new_path = path.dup << key
          render value, new_path, &block

          append(",", path) unless key == data.length - 1
          append("\n", path)
        end

        append(("#{" " * (indent - @indentation)}]"), path)

      else
        output = @struct_only ? yield(:struct, data) : yield(:value, data)
        output = colorize output, data if @color
        append output.to_s, path
      end
    end


    alias append_arrow <<

    ##
    # Add a string with metadata to the data string.

    def append str, metadata=nil
      @meta.concat([metadata] * str.length)
      self.append_arrow str
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
        j   = i-1
        val = arr[i]

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


    CLASS_ORDER = {Fixnum => 2, String => 1, Symbol => 0}

    ##
    # Compares Numerics, Strings, and Symbols and returns true if the left
    # side is 'smaller' than the right side.

    def smaller? left, right
      left.class == right.class && left.to_s < right.to_s ||
        CLASS_ORDER[left.class] < CLASS_ORDER[right.class]
    end
  end
end
