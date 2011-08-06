require 'test/test_helper'

class TestPlayer < Test::Unit::TestCase

  def setup
    @out, @inn = IO.pipe
    @player    = Kronk::Player.new :io => @out
  end


  def test_init
    assert_equal Kronk::Player::InputReader, @player.input.class
    assert_equal @out, @player.input.io
  end

end
