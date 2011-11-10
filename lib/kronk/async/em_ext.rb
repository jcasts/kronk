require 'em-http-request'
__END__

module EventMachine
  class HttpClient
    attr_accessor :k_socket, :k_wsocket

    alias em_init initialize

    def initialize(conn, options)
      @k_socket, @k_wsocket = IO.pipe
      em_init
    end


    alias em_parse_response_header parse_response_header

    def parse_response_header header, version, status
      out = em_parse_response_header header, version, status

      rheader = @response_header

      @k_wsocket << "HTTP/#{rheader.http_version} "
      @k_wsocket << "#{rheader.status} #{rheader.http_reason}\r\n"

      header.each do |key, val|
        @k_wsocket << "#{key}: #{val}\r\n"
      end

      @k_wsocket << "\r\n"

      out
    end


    alias em_on_decoded_body_data on_decoded_body_data

    def on_decoded_body_data data
      @k_wsocket << data
      em_on_decoded_body_data data
    end
  end
end
