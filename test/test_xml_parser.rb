require 'test/test_helper'
require "nokogiri"

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

    @ary_xml = <<-STR
<root>
  <tests>
    <test>A1</test>
    <test>A2</test>
  </tests>
  <tests>
    <test>B1</test>
    <test>B2</test>
  </tests>
  <tests>
    <test>C1</test>
    <test>C2</test>
    <test>
      <test>C3a</test>
      <test>C3b</test>
    </test>
  </tests>
  <tests>
    <test>
      <test>D1a
Content goes here</test>
      <test>D1b</test>
    </test>
    <test>D2</test>
    <tests>
      <test>D3a</test>
      <test>D3b</test>
    </tests>
  </tests>
</root>
    STR
  end


  def test_node_value_arrays
    expected = {
      "root" => [
        ["A1", "A2"],
        ["B1", "B2"],
        ["C1", "C2", ["C3a", "C3b"]],
        {"tests"=>["D3a", "D3b"],
          "test"=>[["D1a\nContent goes here", "D1b"], "D2"]}
      ]
    }

    root_node = Nokogiri.XML @ary_xml do |config|
      config.default_xml.noblanks
    end

    results = Kronk::XMLParser.node_value(root_node.children)
    assert_equal expected, results
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
