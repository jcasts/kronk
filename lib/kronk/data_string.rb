class Kronk

  module DataString

    ##
    # Returns a ruby data string that is diff-able, meaning sorted by
    # Hash keys when available.

    def self.ruby data, struct_only=false, indent=1
      i_width = Kronk.config[:indentation] || 1

      case data

      when Hash
        return "{}" if data.empty?

        output = "{\n"

        sorted_keys = sort_any data.keys

        data_values =
          sorted_keys.map do |key|
            value   = data[key]
            pad     = " " * indent
            subdata = ordered_data_string value, struct_only, indent + i_width
            "#{pad}#{key.inspect} => #{subdata}"
          end

        output << data_values.join(",\n") << "\n" unless data_values.empty?
        output << "#{" " * (indent - i_width)}}"

      when Array
        return "[]" if data.empty?

        output = "[\n"

        data_values =
          data.map do |value|
            pad = " " * indent
            "#{pad}#{ordered_data_string value, struct_only, indent + i_width}"
          end

        output << data_values.join(",\n") << "\n" unless data_values.empty?
        output << "#{" " * (indent - i_width)}]"

      else
        return data.inspect unless struct_only
        return "Boolean" if data == true || data == false
        data.class
      end
    end


    ##
    # Returns a json data string that is diff-able, meaning sorted by
    # Hash keys when available.

    def self.json data, struct_only=false, indent=1
      i_width = Kronk.config[:indentation] || 1
      case data

      when Hash
        return "{}" if data.empty?

        output = "{\n"

        sorted_keys = sort_any data.keys

        data_values =
          sorted_keys.map do |key|
            value   = data[key]
            pad     = " " * indent
            subdata = ordered_data_string value, struct_only, indent + 1
            "#{pad}#{key.to_json}: #{subdata}"
          end

        output << data_values.join(",\n") << "\n" unless data_values.empty?
        output << "#{" " * (indent-1)}}"

      when Array
        return "[]" if data.empty?

        output = "[\n"

        data_values =
          data.map do |value|
            pad = " " * indent
            "#{pad}#{ordered_data_string value, struct_only, indent + 1}"
          end

        output << data_values.join(",\n") << "\n" unless data_values.empty?
        output << "#{" " * (indent-1)}]"

      else
        if struct_only
          data = (data == true || data == false) ? "Boolean" : data.class
        end
        data.to_json
      end
    end
  end
end
