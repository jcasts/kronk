require 'test/test_helper'

class TestCmd < Test::Unit::TestCase

  def test_irb
    with_irb_mock do
      resp = Kronk::Response.new mock_resp("200_response.json")

      Kronk::Cmd.irb resp

      assert_equal resp, $http_response
      assert_equal resp.parsed_body, $response
    end
  end


  def test_irb_no_parser
    with_irb_mock do
      resp = Kronk::Response.new mock_200_response
      Kronk::Cmd.irb resp
      assert_equal resp, $http_response
      assert_equal resp.body, $response
    end
  end
end
