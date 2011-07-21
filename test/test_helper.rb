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


def expect_request req_method, url, options={}
  uri  = URI.parse url

  resp = Kronk::Response.new mock_200_response #mock 'resp'
  resp.stubs(:code).returns(options[:status] || '200')

  http   = mock 'http'
  socket = mock 'socket'
  req    = mock 'req'
  res    = mock 'res'

  res.stubs(:to_hash).returns Hash.new

  data   = options[:data]
  data &&= Hash === data ? Kronk::Request.build_query(data) : data.to_s

  headers = options[:headers] || Hash.new
  headers['User-Agent'] ||= Kronk.config[:user_agents]['kronk']

  socket.expects(:debug_output=)

  Kronk::Request::VanillaRequest.expects(:new).
    with(req_method.to_s.upcase, uri.request_uri, headers).returns req

  http.expects(:request).with(req, data).returns res

  http.expects(:instance_variable_get).with("@socket").returns socket

  Net::HTTP.expects(:new).with(uri.host, uri.port).returns req
  req.expects(:start).yields(http).returns res

  Kronk::Response.expects(:new).returns resp

  yield http, req, resp if block_given?

  resp
end
