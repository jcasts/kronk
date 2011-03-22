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
      # Assert that at least one data point found with the given path is equal
      # to the given match.
      # Supports all DataSet#find_data path types.

      def assert_data_at_equals data, path, match, msg=nil
        last_data = nil
        found     = false

        data_set = Kronk::DataSet.new data
        data_set.find_data path do |d,k,p|
          found     = true
          last_data = d
          break if d == match
        end

        assert found,
          msg || "No data found at #{path.inspect} for #{data.inspect}"

        assert_equal match, last_data, msg
      end
    end
  end
end
