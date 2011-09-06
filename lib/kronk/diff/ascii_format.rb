class Kronk

  class Diff

    ##
    # Format diff with ascii

    class AsciiFormat


      def self.head left, right
        ["--- #{left}", "+++ #{right}"]
      end


      def self.context left, right, info=nil
        "@@ -#{left} +#{right} @@ #{info}"
      end


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
  end
end
