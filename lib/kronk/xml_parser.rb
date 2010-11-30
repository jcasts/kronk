class Kronk

  ##
  # Wrapper class for Nokogiri parser.

  class XMLParser

    ##
    # Takes an xml string and returns a data hash.
    # Ignores blank spaces between tags.

    def self.parse str
      root_node = Nokogiri.XML str do |config|
        config.default_xml.noblanks
      end

      hash = node_value root_node.children
      hash.values.first
    end


    ##
    # Build a hash from a nokogiri xml node.

    def self.node_value xml_node, as_array=false
      case xml_node
      when Nokogiri::XML::Text    then xml_node.text

      # Returns hash or array
      when Nokogiri::XML::NodeSet then node_set_value(xml_node, as_array)

      # Returns node name and value
      when Nokogiri::XML::Element then element_node_value(xml_node)
      end
    end


    ##
    # Returns the value for an xml node set.
    # Can be a Hash, Array, or String

    def self.node_set_value xml_node, as_array=false
      orig = {}
      data = as_array ? Array.new : Hash.new

      xml_node.each do |node|
        node_data, name = node_value node
        return node_data unless name

        case data
        when Array
          data << node_data
        when Hash
          orig[name] ||= node_data

          if data.has_key?(name)
            data[name] = [data[name]] if data[name] == orig[name]
            data[name] << node_data
          else
            data[name] = node_data
          end
        end
      end

      data
    end


    ##
    # Returns an Array containing the value of an element node
    # and its name.

    def self.element_node_value xml_node
      name     = xml_node.name
      datatype = xml_node.attr :type
      is_array = array? xml_node.children, name
      data     = node_value xml_node.children, is_array

      data = case datatype
             when 'symbol'  then data.to_sym
             when 'integer' then data.to_i
             when 'float'   then data.to_f
             else
               data
             end

      [data, name]
    end


    ##
    # Checks if a given node set should be interpreted as an Array.

    def self.array? node_set, parent_name=nil
      names = node_set.map do |n|
        return unless Nokogiri::XML::Element === n
        n.name
      end

      names.uniq.length == 1 && (names.length > 1 ||
      parent_name && (names.first == parent_name ||
      names.first.pluralize == parent_name))
    end
  end
end
