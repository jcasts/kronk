class Kronk


  ##
  # Creates simple diffs as formatted strings or arrays, from two strings or
  # data objects.

  class Diff


    ##
    # Creates a new diff from two data objects.

    def self.new_from_data data1, data2, options={}
      new ordered_data_string(data1, options[:struct]),
          ordered_data_string(data2, options[:struct])
    end


    ##
    # Returns a data string that is diff-able, meaning sorted by
    # Hash keys when available.

    def self.ordered_data_string data, struct_only=false, indent=0
      case data

      when Hash
        output = "{\n"

        key_width = 0
        data.keys.each do |k|
          key_width = k.inspect.length if k.inspect.length > key_width
        end

        data_values =
          data.map do |key, value|
            pad = " " * indent
            subdata = ordered_data_string value, struct_only, indent + 1
            "#{pad}#{key.inspect} => #{subdata}"
          end

        output << data_values.sort.join(",\n") << "\n"
        output << "#{" " * indent}}"

      when Array
        output = "[\n"

        data_values =
          data.map do |value|
            pad = " " * indent
            "#{pad}#{ordered_data_string value, struct_only, indent + 1}"
          end

        output << data_values.join(",\n") << "\n"
        output << "#{" " * indent}]"

      else
        return data.inspect unless struct_only
        return "Boolean" if data == true || data == false
        data.class
      end
    end


    attr_accessor :str1, :str2, :char, :format

    def initialize str1, str2, char=/\r?\n/
      @str1 = str1
      @str2 = str2
      @char = char
      @diff_ary = nil
      @format = Kronk.config[:diff_format] || :ascii_diff
    end


    ##
    # Returns a diff array with the following format:
    #   str1 = "match1\nmatch2\nstr1 val"
    #   str1 = "match1\nin str2\nmore str2\nmatch2\nstr2 val"
    #
    #   Diff.new(str1, str2).create_diff
    #   ["match 1",
    #    [[], ["in str2", "more str2"]],
    #    "match 2",
    #    [["str1 val"], ["str2 val"]]]

    def create_diff
      diff_ary = []
      sub_diff = nil

      arr1 = @str1.split @char
      arr2 = @str2.split @char

      until arr1.empty? && arr2.empty?
        item1, item2 = arr1.shift, arr2.shift

        if item1 == item2
          if sub_diff
            diff_ary << sub_diff
            sub_diff = nil
          end

          diff_ary << item1
          next
        end

        match1 = arr1.index item2
        match2 = arr2.index item1

        if match1
          diff_ary.concat diff_match(item1, match1, arr1, 0, sub_diff)
          sub_diff = nil

        elsif match2
          diff_ary.concat diff_match(item2, match2, arr2, 1, sub_diff)
          sub_diff = nil

        elsif !item1.nil? || !item2.nil?
          sub_diff ||= [[],[]]
          sub_diff[0] << item1 if item1
          sub_diff[1] << item2 if item2
        end
      end

      diff_ary << sub_diff if sub_diff

      diff_ary
    end


    ##
    # Create a diff from a match.

    def diff_match item, match, arr, side, sub_diff
      sub_diff ||= [[],[]]

      index = match - 1
      added = [item]
      added.concat arr.slice!(0..index) if index >= 0

      sub_diff[side].concat(added)
      [sub_diff, arr.shift]
    end


    ##
    # Returns a formatted output as a string.
    # Custom formats may be achieved by passing a block.

    def formatted format=@format, join_char="\n", &block
      block ||= method format

      diff_array.map do |item|
        block.call item.dup
      end.flatten.join join_char
    end


    ##
    # Formats a single diff element to the default diff format.

    def ascii_diff item
      case item
      when String
        "  #{item}"
      when Array
        item[0] = item[0].map{|str| "- #{str}"}
        item[1] = item[1].map{|str| "+ #{str}"}
        item
      else
        "  #{item.inspect}"
      end
    end


    ##
    # Formats a single diff element with colors.

    def color_diff item
      case item
      when String
        item
      when Array
        item[0] = item[0].map{|str| "\033[31m#{str}\033[0m"}
        item[1] = item[1].map{|str| "\033[32m#{str}\033[0m"}
        item
      else
        item.inspect
      end
    end


    ##
    # Returns the number of diffs found.

    def count
      diff_array.select{|i| Array === i }.length
    end


    ##
    # Returns the cached diff array when available, otherwise creates it.

    def diff_array
      @diff_ary ||= create_diff
    end

    alias to_a diff_array


    ##
    # Returns a diff string with the default format.

    def to_s
      formatted
    end
  end
end
