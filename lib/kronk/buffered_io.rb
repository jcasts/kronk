class Kronk

  ##
  # Wrapper for Net::BufferedIO

  class BufferedIO < Net::BufferedIO

    attr_accessor :raw_output

    def initialize io
      super
      @raw_output = nil
    end


    private

    def rbuf_consume len
      str = super
      @raw_output << str if @raw_output
      str
    end
  end
end
