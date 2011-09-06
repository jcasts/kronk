class Kronk::Diff

  class Output

    def initialize diff, opts={}
      @output     = []
      @cached     = nil
      @diff_ary   = diff.diff_array
      @format     = opts[:formatter]     || diff.formatter || AsciiFormat
      @context    = opts[:context]       && opts[:context] + 1
      @join_ch    = opts[:join_char]     || "\n"
      @labels     = Array(opts[:labels]  || ["left", "right"])
      @show_lines = opts[:show_lines]
      @record     = false

      lines1 = diff.str1.lines.count
      lines2 = diff.str2.lines.count
      @cwidth = (lines1 > lines2 ? lines1 : lines2).to_s.length
    end


    def record? i, line1, line2
      next_diff = @diff_ary[i,@context].to_a.find{|da| Array === da} if @context

      if !@context || next_diff
        @record || [@output.length, line1+1, line2+1, 0, 0]

      elsif @record && @context && !next_diff
        scheck = @output.length - (@context - 1)
        subary = @output[scheck..-1].to_a

        if i == @diff_ary.length || !subary.find{|da| Array === da}
          start  = @record[0]
          cleft  = "#{@record[1]},#{@record[3]}"
          cright = "#{@record[2]},#{@record[4]}"
          info   = @output[start].meta[0] if @output[start].respond_to?(:meta)

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
      action = if line1 && !line2
                 :deleted
               elsif !line1 && line2
                 :added
               else
                 :common
               end

      lines = @format.lines [line1, line2], @cwidth if @show_lines
      line  = "#{lines}#{@format.send action, item}"
      line  = Kronk::DataString.new line, item.meta[0] if item.respond_to? :meta
      @record[3] += 1 if line1
      @record[4] += 1 if line2
      line
    end
  end
end
