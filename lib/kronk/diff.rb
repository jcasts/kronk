class Kronk


  ##
  # Creates simple diffs as formatted strings or arrays, from two strings or
  # data objects.

  class Diff

    ##
    # Format diff with ascii

    class AsciiFormat

      def self.lines line_nums, col_width
        out =
          [*line_nums].map do |lnum|
            lnum.to_s.rjust col_width
          end.join "|"

        "#{out} "
      end


      def self.deleted str
        "- #{str}"
      end


      def self.added str
        "+ #{str}"
      end


      def self.common str
        "  #{str}"
      end
    end


    ##
    # Format diff with ascii

    class ColorFormat

      def self.require_win_color
        begin
          require 'Win32/Console/ANSI'
        rescue LoadError
          puts "Warning: You must gem install win32console to use color"
        end
      end


      def self.lines line_nums, col_width
        require_win_color if Kronk.windows?

        out =
          [*line_nums].map do |lnum|
            lnum.to_s.rjust col_width
          end.join "\033[32m"

        "\033[7;31m#{out}\033[0m "
      end


      def self.deleted str
        require_win_color if Kronk.windows?
        "\033[31m- #{str}\033[0m"
      end


      def self.added str
        require_win_color if Kronk.windows?
        "\033[32m+ #{str}\033[0m"
      end


      def self.common str
        "  #{str}"
      end
    end


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

        data_values =
          data.map do |key, value|
            pad = " " * indent
            subdata = ordered_data_string value, struct_only, indent + 1
            "#{pad}#{key.inspect} => #{subdata}"
          end

        output << data_values.sort.join(",\n") << "\n" unless data_values.empty?
        output << "#{" " * indent}}"

      when Array
        output = "[\n"

        data_values =
          data.map do |value|
            pad = " " * indent
            "#{pad}#{ordered_data_string value, struct_only, indent + 1}"
          end

        output << data_values.join(",\n") << "\n" unless data_values.empty?
        output << "#{" " * indent}]"

      else
        return data.inspect unless struct_only
        return "Boolean" if data == true || data == false
        data.class
      end
    end


    ##
    # Adds line numbers to each lines of a String.

    def self.insert_line_nums str, formatter=nil
      format = Diff.formatter formatter || Kronk.config[:diff_format]

      out   = ""
      width = str.lines.count.to_s.length

      str.split("\n").each_with_index do |line, i|
        out << "#{format.lines(i+1, width)}#{line}\n"
      end

      out
    end


    ##
    # Returns a formatter from a symbol or string. Returns nil if not found.

    def self.formatter name
      return AsciiFormat if name == :ascii_diff
      return ColorFormat if name == :color_diff
      Kronk.find_const name rescue name
    end


    attr_accessor :str1, :str2, :char, :formatter, :show_lines

    def initialize str1, str2, char=/\r?\n/
      @str1       = str1
      @str2       = str2
      @char       = char
      @diff_ary   = nil
      @show_lines = Kronk.config[:show_lines]
      @formatter  =
        self.class.formatter(Kronk.config[:diff_format]) || AsciiFormat
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

      arr1 = @str1.split @char
      arr2 = @str2.split @char

      common_list = find_common arr1, arr2

      return [[arr1, arr2]] if common_list.nil?

      last_i1 = 0
      last_i2 = 0

      common_list.each do |c|
        left  = arr1[last_i1...c[1]]
        right = arr2[last_i2...c[2]]

        # add diffs
        diff_ary << [left, right] unless left.empty? && right.empty?

        # add common
        diff_ary.concat arr1[c[1], c[0]]

        last_i1 = c[1] + c[0]
        last_i2 = c[2] + c[0]
      end

      left  = arr1[last_i1..-1]
      right = arr2[last_i2..-1]

      diff_ary << [left, right] unless left.empty? && right.empty?

      diff_ary
    end


    ##
    # Recursively finds common sequences between two arrays and returns
    # them in the order they occur as an array of arrays:
    #   find_common arr1, arr2
    #   #=> [[size, arr1_index, arr2_index], [size, arr1_index, arr2_index],...]

    def find_common arr1, arr2, i1=0, i2=0
      common = longest_common_sequence arr1, arr2

      return unless common

      left_i  = common[1]
      right_i = common[2]

      common[1] = common[1] + i1
      common[2] = common[2] + i2

      out = [common]

      if left_i > 0 && right_i > 0
        new_arr1 = arr1[0...left_i]
        new_arr2 = arr2[0...right_i]

        pre_common = find_common new_arr1, new_arr2, i1, i2
        out = pre_common.concat out if pre_common
      end

      if (common[0] + left_i  < arr1.length) &&
         (common[0] + right_i < arr2.length)

        s1 = left_i  + common[0]
        s2 = right_i + common[0]

        new_arr1 = arr1[s1..-1]
        new_arr2 = arr2[s2..-1]

        post_common = find_common new_arr1, new_arr2, s1+i1, s2+i2
        out.concat post_common if post_common
      end

      out
    end


    ##
    # Finds the longest common sequence between two arrays.

    def longest_common_sequence arr1, arr2
      longest = nil

      i = 0

      while i < arr1.length
        return longest if longest && arr1.length - (i+1) < longest[0]

        j = 0

        while j < arr2.length

          line1 = arr1[i]
          line2 = arr2[j]

          j += 1 and next unless line1 == line2

          k = i
          start_j = j

          while line1 == line2 && k < arr1.length
            k += 1
            j += 1

            line1 = arr1[k]
            line2 = arr2[j]
          end

          len = j - start_j

          longest = [len, i, j-len] if !longest || longest[0] < len

          j += 1
        end
        i += 1
      end

      longest
    end


    ##
    # Returns a formatted output as a string.
    # Supported options are:
    # :join_char:: String - The string used to join lines; default "\n"
    # :show_lines:: Boolean - Insert line numbers or not; default @show_lines
    # :formatter:: Object - The formatter to use; default @formatter

    def formatted options={}
      options = {
        :join_char  => "\n",
        :show_lines => @show_lines,
        :formatter  => @formatter
      }.merge options

      format = options[:formatter]

      line1 = line2 = 0

      lines1 = @str1.lines.count
      lines2 = @str2.lines.count

      width = (lines1 > lines2 ? lines1 : lines2).to_s.length

      diff_array.map do |item|
        case item
        when String
          line1 = line1.next
          line2 = line2.next

          lines = format.lines [line1, line2], width if options[:show_lines]
          "#{lines}#{format.common item}"

        when Array
          item = item.dup

          item[0] = item[0].map do |str|
            line1 = line1.next
            lines = format.lines [line1, nil], width if options[:show_lines]
            "#{lines}#{format.deleted str}"
          end

          item[1] = item[1].map do |str|
            line2 = line2.next
            lines = format.lines [nil, line2], width if options[:show_lines]
            "#{lines}#{format.added str}"
          end

          item
        end
      end.flatten.join options[:join_char]
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
