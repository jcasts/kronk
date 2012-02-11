class Kronk

  class Diff

    ##
    # Format diff with ascii

    class ColorFormat

      def self.head left, right
        ["\033[1;33m--- #{left}", "+++ #{right}\033[0m"]
      end


      def self.context left, right, info=nil
        "\033[1;35m@@ -#{left} +#{right} @@\033[0m #{info}"
      end


      def self.lines line_nums, col_width
        out =
          [*line_nums].map do |lnum|
            lnum.to_s.rjust col_width
          end.join "\033[32m"

        "\033[7;31m#{out}\033[0m "
      end


      def self.deleted str
        rm_color str
        "\033[1;31m- #{str}\033[0m"
      end


      def self.added str
        rm_color str
        "\033[1;32m+ #{str}\033[0m"
      end


      def self.common str
        "  #{str}"
      end


      def self.rm_color str
        str.gsub!(/\e\[[^m]+m/, '')
      end
    end
  end
end
