class Kronk

  ##
  # Simple XML parser that keeps the original xml data.
  # Useful for comparing two xml or two html documents.

  class RawXMLParser

    ##
    # Takes an xml string and returns a data hash.
    # Ignores blank spaces between tags.

    def self.parse str
      doc = Nokogiri.XML str do |config|
        config.default_xml.noblanks
      end

      node_value doc.root
    end


    ##
    # Build a hash from a nokogiri html node.

    def self.node_value xml_node
      case xml_node
      when Nokogiri::XML::Text
        xml_node.text

      # Returns an array
      when Nokogiri::XML::NodeSet
        nodes = []
        xml_node.each{|n| nodes << node_value(n)}
        nodes

      # Returns node name and value
      when Nokogiri::XML::Element
        [xml_node.name, attributes_for(xml_node),
          *node_value(xml_node.children)]
      end
    end


    ##
    # Return the attributes hash for a given xml node.

    def self.attributes_for xml_node
      return unless xml_node.respond_to? :attributes

      attribs = {}

      xml_node.attributes.each do |name, attr_node|
        attribs[name] = attr_node.value
      end

      attribs
    end
  end
end
