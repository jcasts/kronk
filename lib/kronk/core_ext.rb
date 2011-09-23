class Kronk

  ##
  # Data manipulation and retrieval methods for Array and Hash classes.

  module DataExt

    ##
    # Checks if the given path exists and returns the first matching path
    # as an array of keys. Returns false if no path is found.

    def has_path? path
      Kronk::Path.find path, self do |d,k,p|
        return true
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


    ##
    # Finds and replaces the value of any match with the given new value.
    # Returns true if matches were replaced, otherwise false.
    #
    #   data = {:foo => "bar", :foobar => [:a, :b, {:foo => "other bar"}, :c]}
    #   data.replace_at_path "**=*bar", "BAR"
    #   #=> true
    #
    #   data
    #   #=> {:foo => "BAR", :foobar => [:a, :b, {:foo => "BAR"}, :c]}
    #
    # Note: Specifying a limit will allow only "limit" number of items to be
    # set but may yield unpredictible results for non-ordered Hashes.
    # It's also important to realize that arrays are modified starting with
    # the last index, going down.

    def replace_at_path path, value, limit=nil
      count = 0

      Kronk::Path.find path, self do |data, key, path_arr|
        count     = count.next
        data[key] = value

        return true if limit && count >= limit
      end

      return count > 0
    end


    ##
    # Similar to DataExt#replace_at_path but deletes found items.
    # Returns a hash of path/value pairs of deleted items.
    #
    #   data = {:foo => "bar", :foobar => [:a, :b, {:foo => "other bar"}, :c]}
    #   data.replace_at_path "**=*bar", "BAR"
    #   #=> {[:foo] => "bar", [:foobar, 2, :foo] => "other bar"}

    def delete_at_path path, limit=nil
      count = 0
      out   = {}

      Kronk::Path.find path, self do |data, key, path_arr|
        count         = count.next
        out[path_arr] = data[key]

        data.respond_to(:delete_at) ? data.delete_at(key) : data.delete(key)

        return true if limit && count >= limit
      end

      return count > 0
    end
  end
end


Array.send :include, Kronk::DataExt
Hash.send  :include, Kronk::DataExt
