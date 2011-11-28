require "test/unit"
require "kronk/async"
require "mocha"

Kronk.config[:context] = nil


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

MOCK_REQUIRES = Hash.new 0

def mock_require str
  MOCK_REQUIRES[str] += 1
end


def clear_mock_require str
  MOCK_REQUIRES.delete str
end


alias kernel_require require
def require str
  if MOCK_REQUIRES[str] > 0
    MOCK_REQUIRES[str] = MOCK_REQUIRES[str] - 1
    return
  end
  kernel_require str
end


def assert_require req, msg=nil
  assert MOCK_REQUIRES.has_key?(req), msg || "Expected mock require '#{req}'"
  assert_equal 0, MOCK_REQUIRES[req],
    msg || "Expected require '#{req}' #{MOCK_REQUIRES[req]} more times"
end


$catch_exit = nil
alias kernel_exit exit
def exit status=true
  if $catch_exit
    throw :exited, status
  end
  kernel_exit status
end


def assert_exit num=true
  $catch_exit = true
  status = catch :exited do
    yield if block_given?
  end
  $catch_exit = false

  assert_equal num,status,
    "Expected exit status #{num.inspect} but got #{status.inspect}"
end


def expect_compare_output str1, str2=nil, opts={}
  opts = str2 if opts.empty? && Hash === str2
  str2 = str1 if !str2 || Hash === str2
  tim  = opts.delete(:times) || 1

  kronk = Kronk.new opts
  kronk.compare StringIO.new(str1), StringIO.new(str2)

  $stdout.expects(:puts).with(kronk.diff.formatted).times(tim)
end


def expect_request_output str, opts={}
  res = Kronk::Response.new str
  tim = opts.delete(:times) || 1
  $stdout.expects(:puts).with(res.stringify opts).times(tim)
end


def expect_error_output str, name="Error"
  $stderr.expects(:puts).with "\n#{name}: #{str}"
end


IRB = Module.new
def with_irb_mock
  mock_require "irb"

  $stdout.expects(:puts).with "\nHTTP Response is in $http_response"
  $stdout.expects(:puts).with "Response data is in $response\n\n"
  ::IRB.expects :start

  yield

  $http_response = nil
  $response = nil
  clear_mock_require 'irb'
end


def with_config config={}
  old_conf = Kronk.config.dup
  old_conf.each do |k,v|
    old_conf[k] = v.dup if Array === old_conf[k] || Hash === old_conf[k]
  end

  Kronk.instance_variable_set "@config", Kronk.config.merge(config)
  yield

ensure
  Kronk.instance_variable_set "@config", old_conf
end


def expect_request req_method, url, options={}
  uri  = URI.parse url

  resp = Kronk::Response.new(options[:returns] || mock_200_response)
  resp.stubs(:code).returns(options[:status] || '200')
  resp.stubs(:to_hash).returns Hash.new

  http   = mock 'http'
  req    = mock 'req'

  data   = options[:data]
  data &&= Hash === data ? Kronk::Request.build_query(data) : data.to_s

  headers = options[:headers] || Hash.new
  headers['User-Agent'] ||= Kronk::DEFAULT_USER_AGENT

  req.expects(:start).yields(http).returns resp

  Kronk::Request::VanillaRequest.expects(:new).
    with(req_method.to_s.upcase, uri.request_uri, headers).returns req

  Kronk::HTTP.expects(:new).with(uri.host, uri.port).returns req

  http.expects(:request).with(req, data).returns resp

  yield http, req, resp if block_given?

  resp
end
