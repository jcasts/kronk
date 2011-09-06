class Kronk

  ##
  # Creates simple diffs as formatted strings or arrays, from two strings or
  # data objects.

  class Diff

    ##
    # Creates a new diff from two data objects.

    def self.new_from_data data1, data2, opts={}
      new ordered_data_string(data1, opts[:struct]),
          ordered_data_string(data2, opts[:struct])
    end


    ##
    # Returns a data string that is diff-able, meaning sorted by
    # Hash keys when available.

    def self.ordered_data_string data, struct_only=false
      data = Kronk::Path.pathed(data) if Kronk.config[:render_paths]

      case Kronk.config[:render_lang].to_s
      when 'ruby' then DataRenderer.ruby(data, struct_only)
      else
        DataRenderer.json(data, struct_only)
      end
    end


    ##
    # Adds line numbers to each lines of a String.

    def self.insert_line_nums str, formatter=nil
      format = Diff::Output.formatter formatter || Kronk.config[:diff_format]

      out   = ""
      width = str.lines.count.to_s.length

      str.split("\n").each_with_index do |line, i|
        out << "#{format.lines(i+1, width)}#{line}\n"
      end

      out
    end


    attr_accessor :str1, :str2, :char, :output

    def initialize str1, str2, opts={}
      @str1       = str1
      @str2       = str2
      @diff_ary   = nil
      @char       = opts[:char] || /\r?\n/
      @output     = Output.new self, opts
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

      return [[arr1, arr2]] if common_list.empty?

      last_i1 = 0
      last_i2 = 0

      common_list.each do |c|
        next unless c

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

    def find_common arr1, arr2
      used1 = []
      used2 = []

      common = []

      common_sequences(arr1, arr2) do |seq|
        next if used1[seq[1]] || used2[seq[2]]

        next if used1[seq[1], seq[0]].to_a.index(true) ||
                used2[seq[2], seq[0]].to_a.index(true)

        next if used1[seq[1]+seq[0]..-1].to_a.nitems !=
                  used2[seq[2]+seq[0]..-1].to_a.nitems


        used1.fill(true, seq[1], seq[0])
        used2.fill(true, seq[2], seq[0])

        common[seq[1]] = seq
      end

      common
    end


    ##
    # Returns all common sequences between to arrays ordered by sequence length
    # according to the following format:
    #   [[[len1, ix, iy], [len1, ix, iy]],[[len2, ix, iy]]]
    #   # e.g.
    #   [nil,[[1,2,3],[1,2,5]],nil,[[3,4,5],[3,6,9]]

    def common_sequences arr1, arr2, &block
      sequences = []

      arr2_map = {}
      arr2.each_with_index do |line, j|
        arr2_map[line] ||= []
        arr2_map[line] << j
      end

      arr1.each_with_index do |line, i|
        next unless arr2_map[line]

        arr2_map[line].each do |j|
          line1 = line
          line2 = arr2[j]

          k = i
          start_j = j

          while line1 && line1 == line2 && k < arr1.length
            k += 1
            j += 1

            line1 = arr1[k]
            line2 = arr2[j]
          end

          len = j - start_j

          sequences[len] ||= []
          sequences[len] << [len, i, start_j]
        end
      end

      yield_sequences sequences, &block if block_given?

      sequences
    end


    def yield_sequences sequences, dist=0, &block
      while sequences.length > dist
        item = sequences.pop
        next unless item
        item.each(&block)
      end
    end


    ##
    # Returns a formatted output as a string.

    def formatted opts={}
      @output.render
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


# For Ruby 1.9

unless [].respond_to? :nitems
class Array
  def nitems
    self.compact.length
  end
end
end
