class Query
	
	attr_accessor :sample_id

	attr_accessor :response

	attr_accessor :sample_ids


	###################################################################################################
	##
	##
	## FIELDS SPECIFIC TO ROCHE E411
	##
	##
	###################################################################################################

	attr_accessor :sequence_number

	attr_accessor :carrier_number

	attr_accessor :position_number

	attr_accessor :sample_type

	attr_accessor :container_type

	###################################################################################################
	##
	##
	## ROCHE SPECIFIC FIELDS END.
	##
	##
	###################################################################################################

	def parse_field_for_sample_id(fields,index)
		return false if fields[index].blank?
		return false if fields[index].strip.blank?
		
		self.sample_ids = fields[index].strip.split(/\'/)
	
		return true
	end

	def initialize(args)
		line = args[:line]
		unless line.fields[2].empty?
			## do the gsub for roche type.
			## if not successfuul, then parse for one.
			puts "line fields is:"
			puts line.fields[2].to_s
			line.fields[2].scan(/\^{2}(?<sample_id>[A-Za-z0-9]+)\^(?<sequence_number>[0-9]+)\^(?<carrier_number>[a-zA-Z0-9]+)\^(?<position_number>[0-9]+)\^{2}(?<sample_type>[a-zA-Z0-9]+)\^(?<container_type>[a-zA-Z0-9]+)/) { |sample_id,sequence_number,carrier_number,position_number,sample_type,container_type|  

				self.sequence_number = sequence_number
				self.sample_ids = [sample_id]
				self.carrier_number = carrier_number
				self.position_number = position_number
				self.sample_type = sample_type
				self.container_type = container_type
			}

			puts "sequence_number: #{self.sequence_number}, sample id: #{self.sample_id}, carrier number: #{self.carrier_number}, position_number: #{self.position_number}, sample_type: #{self.sample_type}, container_type: #{self.container_type}" 

			fields = line.fields[2].split(/\^/)
			
			parse_field_for_sample_id(fields,1) if self.container_type.blank?
				

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
	def build_response(options={})
		
		responses = []

		one_response = ''

		puts "sample ids are:"
		puts self.sample_ids

		return responses unless sample_ids

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

			responses << (patient.build_response(options) + order.build_response(options.merge({sequence_number: self.sequence_number, carrier_number: self.carrier_number, position_number: self.position_number, sample_type: self.sample_type, container_type: self.container_type})))

		}

		puts "responses are:"
		puts responses.to_s

		return responses
		
	end

end