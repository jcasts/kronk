class Kronk::Diff

  ##
  # Renders diff outputs.

  class Output

    ##
    # Represents one diff section to render
    # (starts with @@-line,len +line,len@@)

    class Section
      attr_accessor :context, :format, :lindex, :rindex, :llen, :rlen,
                    :lmeta, :rmeta

      ##
      # Create a new Section to render, with a formatter, lines column
      # width, and start indexes for left and right side.

      def initialize format, line_num_width=nil, lindex=0, rindex=0
        @format  = format
        @cwidth  = line_num_width
        @lindex  = lindex
        @rindex  = rindex
        @llen    = 0
        @rlen    = 0
        @lmeta   = nil
        @rmeta   = nil
        @lines   = []
        @context = 0
      end


      ##
      # Append a line or diff section to the section.
      # If obj is a String, common section is assumed, if obj is an Array,
      # a diff section is assumed.
      #
      # Metadata is optional but must be an Array of 2 items if given.

      def add obj, meta=nil
        @lmeta, @rmeta = meta if meta && !@lmeta && !@rmeta
        @lmeta = ary_to_path @lmeta if Array === @rmeta
        @rmeta = ary_to_path @rmeta if Array === @rmeta

        if String === obj
          add_common obj

        elsif Array === obj
          left, right = obj
          left.each{|o| add_left o }
          right.each{|o| add_right o }
        end
      end


      ##
      # Create a Path String from an Array. Used when the meta data
      # given for either side of the diff is an Array.

      def ary_to_path ary
        "#{Path::DCH}#{Path.join ary}"
      end


      ##
      # Build the section String output once all lines and meta has been
      # added.

      def render
        cleft  = "#{@lindex+1},#{@llen}"
        cright = "#{@rindex+1},#{@rlen}"

        if @lmeta != @rmeta && @lmeta && @rmeta
          cleft  << " " << @lmeta
          cright << " " << @rmeta
        else
          info = @lmeta || @rmeta
        end

        [@format.context(cleft, cright, info), *@lines]
      end


      private

      def add_common obj # :nodoc:
        @llen    += 1
        @rlen    += 1
        @context += 1

        line_nums =
          @format.lines [@llen+@lindex, @rlen+@rindex], @cwidth if @cwidth

        @lines << "#{line_nums}#{@format.common obj}"
      end


      def add_left obj # :nodoc:
        @llen   += 1
        @context = 0

        line_nums = @format.lines [@llen+@lindex, nil], @cwidth if @cwidth
        @lines << "#{line_nums}#{@format.deleted obj}"
      end


      def add_right obj # :nodoc:
        @rlen   += 1
        @context = 0

        line_nums = @format.lines [nil, @rlen+@rindex], @cwidth if @cwidth
        @lines << "#{line_nums}#{@format.added obj}"
      end
    end


    ##
    # Returns a formatter from a symbol or string. Returns nil if not found.

    def self.formatter name
      return unless name

      return name        if Class === name
      return AsciiFormat if name.to_s =~ /^ascii(_diff)?$/
      return ColorFormat if name.to_s =~ /^color(_diff)?$/
      Kronk.find_const name

    rescue NameError
      raise Kronk::Error, "No such formatter: #{name.inspect}"
    end


    attr_accessor :labels, :show_lines, :join_ch, :context, :format


    ##
    # Create a new Kronk::Diff::Output instance.
    # Options supported are:
    # :context:: Integer - Number of context lines around diffs; default 3
    # :diff_format:: String/Object - Formatter for the diff; default AsciiFormat
    # :join_char:: String - Vharacter to join diff sections with; default \n
    # :labels:: Array - Left and right names to display; default %w{left right}
    # :show_lines:: Boolean - Show lines in diff; default false

    def initialize opts={}
      @format =
        self.class.formatter(opts[:format] || Kronk.config[:diff_format]) ||
        AsciiFormat

      @context = Kronk.config[:context]
      @context = opts[:context] if opts[:context] || opts[:context] == false

      @join_ch = opts[:join_char] || "\n"

      @labels      = Array(opts[:labels])
      @labels[0] ||= "left"
      @labels[1] ||= "right"

      @show_lines = opts[:show_lines] || Kronk.config[:show_lines]
      @section    = false
    end


    ##
    # Determine if index i is a part of a section to render, including
    # surrounding context.

    def section? i, diff_ary
       !@context ||
        !!diff_ary[i,@context+1].to_a.find{|da| Array === da}
    end


    ##
    # Determine if index i is the beginning of a diff section to render,
    # including surrounding context.

    def start_section? i, diff_ary
      !@section && section?(i, diff_ary)
    end


    ##
    # Determine if index i is the end of a diff section to render, including
    # surrounding context.

    def end_section? i, diff_ary
      @section &&
        (i >= diff_ary.length ||
         !section?(i, diff_ary) && @context && @section.context >= @context)
    end


    ##
    # Determine the width of the line number column from a diff Array.

    def line_col_width diff_ary
      lines1, lines2 = diff_ary.inject([0,0]) do |prev, obj|
        if Array === obj
          [prev[0] + obj[0].length, prev[1] + obj[1].length]
        else
          [prev[0] + 1, prev[1] + 1]
        end
      end

      (lines1 > lines2 ? lines1 : lines2).to_s.length
    end


    ##
    # Render a diff String from a diff Array, with optional metadata.
    #
    # The meta argument must be an Array of 2 Arrays, one for each side of
    # the diff.

    def render diff_ary, meta=[]
      output = []
      output << @format.head(*@labels)

      line1 = line2 = 0
      lwidth = line_col_width diff_ary if @show_lines

      diff_ary.each_with_index do |item, i|
        @section = Section.new @format, lwidth, line1, line2 if
          start_section? i, diff_ary

        @section.add item, meta[i] if @section

        line1 += Array === item ? item[0].length : 1
        line2 += Array === item ? item[1].length : 1

        if end_section?(i+1, diff_ary)
          output.concat @section.render
          @section = false
        end
      end

      output.join(@join_ch)
    end
  end
end
