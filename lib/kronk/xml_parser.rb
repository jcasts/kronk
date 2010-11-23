class Kronk

  ##
  # Wrapper class for Nokogiri parser.

  class XMLParser

    ##
    # Takes an xml string and returns a data hash.

    def self.parse str
      root_node = Nokogiri.parse str
      build_hash root_node.children
    end


    ##
    # Build a hash from a nokogiri xml node.

    def self.build_hash xml_node, hash={}
      case xml_node

      when Nokogiri::XML::Element
        name = xml_node.name
        data = build_hash xml_node.children


        data = [*data.values[0]] if
              Hash === data && data.keys.length == 1 &&
                data.keys.first.pluralize == name

        if hash.has_key?(name)
          if Array === data
            hash[name] = [*hash[name]].concat data
          else
            hash[name] = [*hash[name]] << data
          end
        else
          hash[name] = data
        end


      when Nokogiri::XML::NodeSet
        return if xml_node.empty?
        return xml_node[0].to_s if xml_node.length == 1 &&
          Nokogiri::XML::Text === xml_node.first

        xml_node.each do |node|
          name = node.name
          build_hash node, hash
        end

        return hash
      end
    end
  end
end
