require 'minitest/autorun'
require 'ruby_astm'

class TestRealTimeDb < Minitest::Test
	
	def test_put_real_time_data

		$redis = Redis.new

		r = RealTimeDb.new({
			"IMMUNO" => "Aakash",
			"BIOCHEM" => "Priya",
			"BIOCHEM-EXL" => "Mehraj",
			"BIOCHEM-ELECTROLYTE" => "Mehraj",
			"HEMAT" => "Afreen",
			"URINE" => "Afreen",
			"OUTSOURCE" => "Afreen"
		},JSON.parse(IO.read("/home/bhargav/Downloads/ml-micro-analysis-firebase-adminsdk-3t7e3-be32178718.json")))

		p = Poller.new(nil,r)

	    record = []
	    
	    29.times do |i|

	      if i == 7
	        record[i] = "pre_op_package"
	      elsif i == 24
	        record[i] = "edta5521232--"
	      elsif i == 25
	        record[i] = "serum55212321--"
	      elsif i == 26
	        record[i] = "plasma55212312--"
	      elsif i == 27
	        record[i] = "fluoride552123123--"
	      elsif i == 28
	        record[i] = "urine55212312--"
	      elsif i == 29
	        record[i] = "esr12213213--"
	      else
	        record[i] = ""
	      end

	    end

	    tests_hash = p.build_tests_hash(record)
	    
	    p.merge_with_requisitions_hash(Time.now.to_i,tests_hash)

	end

end