class Query
	
	attr_accessor :sample_id

	attr_accessor :response

	attr_accessor :sample_ids

	def parse_field_for_sample_id(fields,index)
		return false if fields[index].blank?
		return false if fields[index].strip.blank?
		self.sample_ids = fields[index].strip.split(/\'/)
		return true
	end

	def initialize(args)
		line = args[:line]
		unless line.fields[2].empty?
			fields = line.fields[2].split(/\^/)
			if parse_field_for_sample_id(fields,1) == false
				parse_field_for_sample_id(fields,2)
			end
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

		puts "sample ids are:"
		puts self.sample_ids

		self.sample_ids.each_with_index {|sid,key|
			puts "doing sample id: #{sid}"
			## tests are got from the requisitions hash.
			tests = get_tests(sid)
			puts "tests are: #{tests}"
			## default sequence number is 0 (THIS MAY LEAD TO PROBLEMS.)
			sequence_number = "#{key.to_s}"

			## default patient id:
			patient_id = "abcde#{Time.now.to_i.to_s}"
			
			patient = Patient.new({:sequence_number => sequence_number, :patient_id => patient_id})
			
			order = Order.new({:sequence_number => patient.sequence_number, :specimen_id => sid, :tests => tests, :priority => "R"})

			responses << (patient.build_response + order.build_response)

		}

		puts "responses are:"
		puts responses.to_s

		return responses
		
	end

end