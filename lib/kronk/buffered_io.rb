class Kronk

  ##
  # Wrapper for Net::BufferedIO

  class BufferedIO < Net::BufferedIO

    attr_accessor :raw_output
    attr_accessor :response

    def initialize io
      super
      @raw_output = nil
      @response   = nil
    end


    def rewind
      @rbuf.replace @raw_output if @raw_output
    end


    def clear
      @rbuf = ""
      @raw_output = nil
      @response   = nil
    end


    private

    def rbuf_fill
      rbuf_size = @rbuf.length
      super
    ensure
      @raw_output << @rbuf[rbuf_size..-1] if @raw_output
    end
  end
end
