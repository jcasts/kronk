require "test/unit"
require "kronk"
require "mocha"


def mock_200_response
  @mock_200 ||= File.read 'test/mocks/200_response.txt'
end


def mock_300_response
  @mock_300 ||= File.read 'test/mocks/301_response.txt'
end
