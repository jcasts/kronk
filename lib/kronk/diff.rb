class Kronk

  class Diff

    attr_accessor :str1, :str2, :char

    def initialize str1, str2, char=/\r?\n/
      @str1 = str1
      @str2 = str2
      @char = char
      @diff_ary = nil
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
          index   = match1 - 1
          removed = [item1]
          removed.concat arr1.slice(0..index) if index > 0

          diff_ary << [removed, []]
          diff_ary << arr1.shift

        elsif match2
          index = match2 - 1
          added = [item2]
          added.concat arr2.slice(0..index) if index > 0

          diff_ary << [[], added]
          diff_ary << arr2.shift

        elsif !item1.nil? && !item2.nil?
          sub_diff ||= [[],[]]
          sub_diff[0] << item1
          sub_diff[1] << item2
        end
      end

      diff_ary << sub_diff if sub_diff

      diff_ary
    end


    ##
    # Returns a formatted output as a string.
    # Custom formats may be achieved by passing a block.

    def formatted join_char="\n", &block
      block ||= method :default_item_format

      diff_array.map do |item|
        block.call item
      end.flatten.join join_char
    end


    ##
    # Formats a single diff element to the default diff format.

    def default_item_format item
      case item
      when String
        item
      when Array
        item[0].map!{|str| "- #{str}"}
        item[1].map!{|str| "+ #{str}"}
        item
      else
        item.inspect
      end
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
