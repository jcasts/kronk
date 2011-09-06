class Kronk

  ##
  # A String with per-line metadata.

  class DataString < String

    attr_accessor :meta

    def initialize str="", metadata=nil
      @meta = [metadata].compact * str.length
      super str
    end


    ##
    # Add a line with metadata to the string.

    def append str, metadata=nil
      dstr = self.class.new str
      dstr.meta = [metadata] * str.length
      self << dstr
    end


    def << str
      if str.class == self.class
        @meta.concat str.meta
      else
        @meta.concat([@meta.last] * str.length)
      end
      super str
    end


    def [] arg
      dstr = self.class.new super
      dstr.meta = @meta[arg]
      dstr
    end


    def split pattern=$;, *more
      arr      = super
      i        = 0
      interval = (self.length - arr.join.length) / (arr.length - 1)

      arr.map do |str|
        ds = self.class.new str
        ds.meta = @meta[i,str.length]
        i += str.length + interval
        ds
      end
    end


    def meta_by_line
      output = ""
      split.each do |line|
        output << line.meta.first.to_s << "   " << line << "\n"
      end
      output
    end
  end


  ##
  # Creates ordered data strings for rendering to the output.

  module DataRenderer

    ##
    # Returns a ruby data string that is diff-able, meaning sorted by
    # Hash keys when available.

    def self.ruby data, struct_only=false
      ordered_data_string data, struct_only do |type, obj|
        case type
        when :key_assign then " =>"
        when :key        then obj.inspect
        when :value      then obj.inspect
        when :struct
          (obj == true || obj == false) ? "Boolean" : obj.class
        end
      end
    end


    ##
    # Returns a json data string that is diff-able, meaning sorted by
    # Hash keys when available.

    def self.json data, struct_only=false
      ordered_data_string data, struct_only do |type, obj|
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
    end


    ##
    # Turns a data set into an ordered string output for diff-ing.

    def self.ordered_data_string data, struct_only=false, path=[], &block
      i_width  = Kronk.config[:indentation] || 1
      indent   = (path.length + 1) * i_width
      pad      = " " * indent
      path_str = Path.join path

      case data

      when Hash
        return DataString.new("{}", path_str) if data.empty?
        output = DataString.new "{\n", path_str

        sorted_keys = sort_any data.keys

        data_values =
          sorted_keys.map do |key|
            value    = data[key]
            new_path = path.dup << key
            subdata  = ordered_data_string value, struct_only, new_path, &block
            line     = "#{pad}#{ yield(:key, key) }#{ yield(:key_assign) } "
            line     = DataString.new line, path_str
            line << subdata
          end

        data_values.each_with_index do |val, i|
          val << "," unless i == data_values.length - 1
          output << val << "\n"
        end

        output.append(("#{" " * (indent - i_width)}}"), path_str)

      when Array
        return DataString.new("[]", path_str) if data.empty?
        output = DataString.new "[\n", path_str

        data_values =
          (0...data.length).map do |key|
            value    = data[key]
            new_path = path.dup << key
            subdata  = ordered_data_string value, struct_only, new_path, &block
            line     = DataString.new pad, path_str
            line << subdata
          end

        data_values.each_with_index do |val, i|
          val << "," unless i == data_values.length - 1
          output << val << "\n"
        end

        output.append(("#{" " * (indent - i_width)}]"), path_str)

      else
        output = struct_only ? yield(:struct, data) : yield(:value, data)
        DataString.new(output.to_s, path_str)
      end
    end


    ##
    # Sorts an array of any combination of string, integer, or symbols.

    def self.sort_any arr
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

    def self.smaller? left, right
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
