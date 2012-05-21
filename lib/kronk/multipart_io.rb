class Kronk

  class MultipartIO

    attr_reader :parts, :curr_part

    def initialize *parts
      @parts     = []
      @curr_part = 0

      parts.each do |part|
        add part
      end
    end


    def add part
      if String === part
        @parts << StringIO.new(part)

      elsif part.respond_to?(:read)
        @parts << part

      else
        raise ArgumentError, "Invalid part #{part.inspect}"
      end

      @curr_part ||= @parts.length - 1
      @parts.last
    end


    def close
      @parts.each(&:close)
      nil
    end


    def read bytes=nil
      return read_all if bytes.nil?
      return if @parts.empty? || eof?

      buff = ""

      until @curr_part.nil?
        bytes = bytes - buff.bytes.count
        buff << @parts[@curr_part].read(bytes).to_s
        break if buff.bytes.count >= bytes

        @curr_part += 1
        @curr_part = nil if @curr_part >= @parts.length
      end

      return if buff.empty?
      buff
    end


    def read_all
      return "" if eof?

      out = @parts[@curr_part..-1].inject("") do |out, curr|
        @curr_part += 1
        out << curr.read
      end

      @curr_part = nil
      out
    end


    def eof?
      @curr_part.nil?
    end


    def size
      total = 0

      @parts.each do |part|
        return nil unless part.respond_to?(:size) && part.size
        total += part.size
      end

      total
    end
  end
end
