class Kronk::Diff

  class Output

    ##
    # Returns a formatter from a symbol or string. Returns nil if not found.

    def self.formatter name
      return unless name

      return name        if Class === name
      return AsciiFormat if name == :ascii_diff
      return ColorFormat if name == :color_diff
      Kronk.find_const name rescue name
    end


    def self.attr_rm_cache *attrs # :nodoc:
      self.send :attr_reader, *attrs

      attrs.each do |attr|
        define_method "#{attr}=" do |value|
          if send(attr) != value
            instance_variable_set("@#{attr}", value)
            instance_variable_set("@cached", nil)
          end
        end
      end
    end


    attr_rm_cache :labels, :show_lines, :join_ch, :context, :format, :diff_ary


    def initialize diff, opts={}
      @output     = []
      @cached     = nil
      @diff       = diff

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
      @record     = false

      lines1 = diff.str1.lines.count
      lines2 = diff.str2.lines.count
      @cwidth = (lines1 > lines2 ? lines1 : lines2).to_s.length
    end


    def record? i, line1, line2
      if @context
        clen = @context + 1
        next_diff = @diff_ary[i,clen].to_a.find{|da| Array === da}
      end

      if !clen || next_diff
        @record || [@output.length, line1+1, line2+1, 0, 0, []]

      elsif @record && clen && !next_diff
        scheck = @output.length - (clen - 1)
        subary = @output[scheck..-1].to_a

        if i == @diff_ary.length || !subary.find{|da| Array === da}
          start  = @record[0]
          cleft  = "#{@record[1]},#{@record[3]}"
          cright = "#{@record[2]},#{@record[4]}"
          info   = @record[5]

          if info[0] != info[1] && info[0] && info[1]
            cleft  << " " << info[0]
            cright << " " << info[1]
            info = nil
          else
            info = info[0] || info[1]
          end

          @output[start,0] = @format.context cleft, cright, info
          false

        else
          @record
        end

      else
        @record
      end
    end


    def render force=false
      self.diff_ary = @diff.diff_array

      return @cached if !force && @cached
      @output << @format.head(*@labels)

      line1 = line2 = 0

      0.upto(@diff_ary.length) do |i|
        item = @diff_ary[i]
        @record = record? i, line1, line2

        case item
        when String
          line1 = line1.next
          line2 = line2.next
          @output << make_line(item, line1, line2) if @record

        when Array
          sides = [[],[]]

          item[0].each do |ditem|
            line1 = line1.next
            sides[0] << make_line(ditem, line1, nil) if @record
          end

          item[1].each do |ditem|
            line2 = line2.next
            sides[0] << make_line(ditem, nil, line2) if @record
          end

          @output << sides if @record
        end
      end

      @cached = @output.flatten.join(@join_ch)
    end

    alias to_s render


    def make_line item, line1, line2
      if line1 && !line2
        @record[5][0] ||= item.meta.first if Kronk::DataString === item
        action = :deleted
      elsif !line1 && line2
        @record[5][1] ||= item.meta.first if Kronk::DataString === item
        action = :added
      else
        @record[5][0] ||= @record[5][1] ||= item.meta.first if
          Kronk::DataString === item
        action = :common
      end

      lines = @format.lines [line1, line2], @cwidth if @show_lines
      line  = "#{lines}#{@format.send action, item}"
      @record[3] += 1 if line1
      @record[4] += 1 if line2
      line
    end
  end
end
