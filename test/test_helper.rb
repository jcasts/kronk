require "test/unit"
require "kronk"
require "mocha"


def mock_200_response
  @mock_200 ||= File.read 'test/mocks/200_response.txt'
end


def mock_301_response
  @mock_301 ||= File.read 'test/mocks/301_response.txt'
end


def mock_302_response
  @mock_302 ||= File.read 'test/mocks/302_response.txt'
end
