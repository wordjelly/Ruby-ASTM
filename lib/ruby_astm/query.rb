class Query
	
	attr_accessor :sample_id

	attr_accessor :response

	attr_accessor :sample_ids

	def initialize(args)
		line = args[:line]
		unless line.fields[2].empty?
			fields = line.fields[2].split(/\^/)
			sample_id = fields[1].strip
			self.sample_ids = sample_id.split(/\`/)
		end
	end

	def get_tests(sample_id)
		tests = []
		sample_tests = $redis.hget(Poller::REQUISITIONS_HASH,sample_id)
		unless sample_tests.blank?
			tests = JSON.parse(sample_tests)
		end
		tests
	end

	## each query will build one patient and one order inside it.
	## the order can have many tests.
	def build_response(variables=nil)
		
		responses = []

		one_response = ''

		self.sample_ids.each_with_index {|sid,key|

			## tests are got from the requisitions hash.
			tests = get_tests(sid)

			## default sequence number is 0 (THIS MAY LEAD TO PROBLEMS.)
			sequence_number = "#{key.to_s}"

			## default patient id:
			patient_id = "abcde#{Time.now.to_i.to_s}"
			
			patient = Patient.new({:sequence_number => sequence_number, :patient_id => patient_id})
			
			order = Order.new({:sequence_number => patient.sequence_number, :specimen_id => sid, :tests => tests, :priority => "R"})

			responses << (patient.build_response + order.build_response)

		}

		return [one_response]
		
	end

end