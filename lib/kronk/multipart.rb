class Kronk

  ##
  # Builder for the body of a multipart request.

  class Multipart

    # An array of parts for the multipart body.
    attr_reader :parts

    # The separator used between parts.
    attr_reader :boundary


    def initialize boundary
      @boundary = boundary
      @parts    = []
    end


    ##
    # Add a new part to the body.

    def add name, value, headers=nil
      headers ||= {}

      headers['content-disposition'] = "form-data; name=\"#{name}\""

      if value.respond_to?(:path)
        headers['content-disposition'] <<
          "; filename=\"#{File.basename value.path}\""

        headers['Content-Type'] ||= MIME::Types.of(value.path)[0]
        headers['Content-Type'] &&= headers['Content-Type'].to_s
      end

      if value.respond_to?(:read)
        headers['Content-Type']              ||= "application/octet-stream"
        headers['Content-Transfer-Encoding'] ||= 'binary'
      end

      parts << [headers, value]
    end


    ##
    # Convert the instance into a MultipartIO instance.

    def to_io
      io   = Kronk::MultipartIO.new
      buff = ""

      parts.each do |(headers, value)|
        buff << "--#{@boundary}\r\n"
        buff << "content-disposition: #{headers['content-disposition']}\r\n"

        headers.each do |hname, hvalue|
          next if hname == 'content-disposition'
          hvalue = hvalue.to_s.inspect if hvalue.to_s.index ":"
          buff << "#{hname}: #{hvalue}\r\n"
        end

        buff << "\r\n"

        if value.respond_to?(:read)
          io.add buff.dup
          io.add value
          buff.replace ""
        else
          buff << value.to_s
        end

        buff << "\r\n"
      end

      buff << "--#{@boundary}--"
      io.add buff

      io
    end
  end
end
