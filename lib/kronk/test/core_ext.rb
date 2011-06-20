class Kronk

  module Test

    ##
    # Data manipulation and retrieval methods for Array and Hash classes.

    module DataExt

      ##
      # Checks if the given path exists and returns the first matching path
      # as an array of keys. Returns false if no path is found.

      def has_path? path
        Kronk::Path.find path, self do |d,k,p|
          return !!p
        end

        false
      end


      ##
      # Looks for data at paths matching path. Returns a hash of
      # path array => data value pairs.
      #
      # If given a block will pass the parent data structure, the key
      # or index of the item at given path, and the full path
      # as an array of keys for each found path.
      #
      #   data = {:foo => "bar", :foobar => [:a, :b, {:foo => "other bar"}, :c]}
      #   data.find_data "**/foo" do |parent, key, path|
      #     p path
      #     p parent[key]
      #     puts "---"
      #   end
      #
      #   # outputs:
      #   # [:foo]
      #   # "bar"
      #   # ---
      #   # [:foobar, 2, :foo]
      #   # "other bar"
      #   # ---
      #
      #   # returns:
      #   # {[:foo] => "bar", [:foobar, 2, :foo] => "other bar"}

      def find_data path, &block
        Kronk::Path.find path, self, &block
      end
    end
  end
end


Array.send :include, Kronk::Test::DataExt
Hash.send :include, Kronk::Test::DataExt
