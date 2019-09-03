require 'minitest/autorun'
require 'ruby_astm'

class TestPfInterface < Minitest::Test

	def test_init
		k = Pf_Lab_Interface.new(nil,"abc")
		k.get_checkpoint
	end

end	