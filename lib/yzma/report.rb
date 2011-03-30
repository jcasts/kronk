class Yzma

  class Report

    attr_accessor :data, :header, :footer

    def initialize name
      @name = name
      @data = []
      @header = "#{@name} #{Time.now}\n"
      @footer = "\n"
    end


    ##
    # Adds data and a related piece of data identification to
    # the report.

    def add identifier, data
      @data << [identifier, data]
    end


    ##
    # Generates and writes the report to the given IO instance.
    # Defaults to STDOUT.

    def write io=$stdout
      io << @header

      @data.each do |identifier, data|
        if block_given?
          io << yield(identifier, data)
        else
          io << "\n#{identifier.inspect}\n#{data.inspect}\n"
        end
      end

      io << @footer
    end
  end
end
