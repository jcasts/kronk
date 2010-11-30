require 'test/test_helper'

class TestXmlParser < Test::Unit::TestCase

  def setup
    @xml = <<-STR
<root>
  <tests>
    <test>
      <t>1</t>
      <t>2</t>
    </test>
    <test>2</test>
    <foo>bar</foo>
  </tests>
  <subs>
    <sub>a</sub>
    <sub>b</sub>
  </subs>
  <acks>
    <ack>
      <ack>12</ack>
      <ack>34</ack>
    </ack>
    <ack>
      <ack>56</ack>
      <ack>78</ack>
    </ack>
  </acks>
</root>
    STR
  end


  def test_parse
    data = Kronk::XMLParser.parse @xml
    expected = {
      "acks"=>[["12", "34"], ["56", "78"]],
      "tests"=>{
        "foo"=>"bar",
        "test"=>[["1", "2"], "2"]
      },
      "subs"=>["a", "b"]
    }

    assert_equal expected, data
  end
end
