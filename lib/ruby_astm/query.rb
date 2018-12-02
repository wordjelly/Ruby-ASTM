class Query
	
	attr_accessor :sample_id

	attr_accessor :response

	def initialize(args)
		line = args[:line]
		unless line.fields[2].empty?
			fields = line.fields[2].split(/\^/)
			self.sample_id = fields[1].strip
		end
	end

	## each query will build one patient and one order inside it.
	## the order can have many tests.
	def build_response(variables=nil)
		## so the response is thus incoming.
=begin		
		variables ||= {
			:sequence_number => "0",
			:patient_id => "abcde",
			:specimen_id => self.sample_id,
			:tests => ["TRIG"],
			:priority => "R"
		}	
=end

		## tests are got from the requisitions hash.
		tests = []
		sample_tests = $redis.hget(Poller::REQUISITIONS_HASH,self.sample_id)
		unless sample_tests.blank?
			tests = JSON.parse(sample_tests)
		end

		## default sequence number is 0 (THIS MAY LEAD TO PROBLEMS.)
		sequence_number = "0"

		## default patient id:
		patient_id = "abcde"

		patient = Patient.new({:sequence_number => sequence_number, :patient_id => patient_id})
		
		order = Order.new({:sequence_number => patient.sequence_number, :specimen_id => self.sample_id, :tests => tests, :priority => "R"})

		return patient.build_response + order.build_response
		
	end

end