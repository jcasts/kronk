require 'em-http-request'

module EventMachine
  class HttpClient
    attr_accessor :raw_response

    alias em_parse_response_header parse_response_header

    def parse_response_header header, version, status
      out = em_parse_response_header header, version, status

      rheader = @response_header

      @raw_response = "HTTP/#{rheader.http_version} "
      @raw_response << "#{rheader.status} #{rheader.http_reason}\r\n"

      header.each do |key, val|
        @raw_response << "#{key}: #{val}\r\n"
      end

      @raw_response << "\r\n"

      out
    end


    alias em_on_decoded_body_data on_decoded_body_data

    def on_decoded_body_data data
      @raw_response << data
      em_on_decoded_body_data data
    end
  end
end
