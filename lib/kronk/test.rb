class Kronk

  ##
  # Test module that includes kronk assertions, request helper methods,
  # and core extensions.

  module Test
    require 'kronk/core_ext'
    require 'kronk/test/assertions'
    require 'kronk/test/helper_methods'

    include Assertions
    include HelperMethods
  end
end
