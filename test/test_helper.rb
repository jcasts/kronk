require "test/unit"
require "kronk"
require "mocha"


def mock_resp name
  File.read File.join("test/mocks", name)
end


def mock_200_response
  @mock_200 ||= File.read 'test/mocks/200_response.txt'
end


def mock_301_response
  @mock_301 ||= File.read 'test/mocks/301_response.txt'
end


def mock_302_response
  @mock_302 ||= File.read 'test/mocks/302_response.txt'
end


def mock_data
  {
    "root" => [
      ["B1", "B2"],
      ["A1", "A2"],
      ["C1", "C2", ["C3a", "C3b"]],
      {:tests=>["D3a", "D3b"],
      "test"=>[["D1a\nContent goes here", "D1b"], "D2"]}
    ],
    "acks"=>[[56, 78], ["12", "34"]],
    "tests"=>{
      :foo => :bar,
      "test"=>[[1, 2], 2.123]
    },
    "subs"=>["a", "b"]
  }
end
