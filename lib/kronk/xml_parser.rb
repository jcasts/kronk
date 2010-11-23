class Kronk

  ##
  # Wrapper class for Nokogiri parser.

  class XMLParser

    ##
    # Takes an xml string and returns a data hash.

    def self.parse str
      build_hash Nokogiri.parse(xml_doc)
    end


    ##
    # Build a hash from a nokogiri xml document.

    def self.build_hash xml_doc
    end
  end
end
