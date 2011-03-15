class Kronk

  class Diff

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
  end
end
