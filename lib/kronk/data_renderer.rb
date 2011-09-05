class Kronk

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

    def self.ordered_data_string data, struct_only=false, indent=nil, &block
      i_width  = Kronk.config[:indentation] || 1
      indent ||= 0
      indent += i_width

      case data

      when Hash
        return "{}" if data.empty?

        output = "{\n"

        sorted_keys = sort_any data.keys

        data_values =
          sorted_keys.map do |key|
            value   = data[key]
            pad     = " " * indent
            subdata = ordered_data_string value, struct_only, indent, &block
            "#{pad}#{ yield(:key, key) }#{ yield(:key_assign) } #{subdata}"
          end

        output << data_values.join(",\n") << "\n"
        output << "#{" " * (indent - i_width)}}"

      when Array
        return "[]" if data.empty?

        output = "[\n"

        data_values =
          data.map do |value|
            pad = " " * indent
            "#{pad}#{ordered_data_string value, struct_only, indent, &block}"
          end

        output << data_values.join(",\n") << "\n"
        output << "#{" " * (indent - i_width)}]"

      else
        struct_only ? yield(:struct, data) : yield(:value, data)
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
