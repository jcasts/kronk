class Kronk

  module Test

    module Assertions

      ##
      # Assert that the given path exists in data.
      # Supports all DataSet#find_data path types.

      def assert_data_at data, path, msg=nil
        msg ||= "No data found at #{path.inspect} for #{data.inspect}"
        found = false

        data_set = Kronk::DataSet.new data
        data_set.find_data path do |d,k,p|
          found = true
          break
        end

        assert found, msg
      end


      ##
      # Assert that the given path doesn't exist in data.
      # Supports all DataSet#find_data path types.

      def assert_no_data_at data, path, msg=nil
        msg ||= "Data found at #{path.inspect} for #{data.inspect}"
        found = false

        data_set = Kronk::DataSet.new data
        data_set.find_data path do |d,k,p|
          found = true
          break
        end

        assert !found, msg
      end


      ##
      # Assert that at least one data point found with the given path is equal
      # to the given match.
      # Supports all DataSet#find_data path types.

      def assert_data_at_equal data, path, match, msg=nil
        last_data = nil
        found     = false

        data_set = Kronk::DataSet.new data
        data_set.find_data path do |d,k,p|
          found     = true
          last_data = d[k]
          break if d[k] == match
        end

        assert found,
          msg || "No data found at #{path.inspect} for #{data.inspect}"

        assert_equal match, last_data, msg
      end


      ##
      # Assert that no data points found with the given path are equal
      # to the given match.
      # Supports all DataSet#find_data path types.

      def assert_data_at_not_equal data, path, match, msg=nil
        last_data = nil

        data_set = Kronk::DataSet.new data
        data_set.find_data path do |d,k,p|
          last_data = d[k]
          break if d[k] == match
        end

        assert_not_equal match, last_data, msg
      end


      ##
      # Makes request to both uris and asserts that the parsed data they
      # return is equal. Compares response body if data is unparsable.
      # Supports all options of Kronk.compare.

      def assert_equal_responses uri1, uri2, options={}
        resp1 = Kronk.retrieve_data_string uri1, options
        resp2 = Kronk.retrieve_data_string uri2, options

        assert_equal resp1, resp2
      end
    end
  end
end
