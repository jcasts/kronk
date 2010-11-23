class Kronk

  ##
  # Wrapper class for Nokogiri parser.

  class XMLParser

    ##
    # Takes an xml string and returns a data hash.

    def self.parse str
      root_node = Nokogiri.XML str do |config|
        config.default_xml.noblanks
      end

      hash = build_hash root_node.children
      hash.values.first
    end


    ##
    # Build a hash from a nokogiri xml node.

    def self.build_hash xml_node, hash={}
      case xml_node

      when Nokogiri::XML::Element
        name     = xml_node.name
        datatype = xml_node.attr :type
        data     = build_hash xml_node.children

        data = case datatype
               when 'symbol'  then data.to_sym
               when 'integer' then data.to_i
               when 'float'   then data.to_f
               else
                 data
               end

        data = [*data.values[0]] if
          Hash === data && data.keys.length == 1 &&
            (data.keys.first.pluralize == name || data.keys.first == name)

        if hash.has_key?(name)
          parent_depth = get_depth hash[name]
          child_depth  = get_depth data

          hash[name] = [hash[name]] unless parent_depth > child_depth
          hash[name] << data

        else
          hash[name] = data
        end

        return hash

      when Nokogiri::XML::NodeSet
        return if xml_node.empty?
        return xml_node[0].text if xml_node.length == 1 &&
          Nokogiri::XML::Text === xml_node[0]

        xml_node.each do |node|
          build_hash node, hash
        end

        return hash
      end
    end


    ##
    # Returns the depth of an array.

    def self.get_depth ary
      depth = 0
      curr  = [ary]
      while Array === curr.first
        curr = curr.first
        depth = depth.next
      end

      depth
    end
  end
end
