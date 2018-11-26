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
		variables ||= {
			:sequence_number => "0",
			:patient_id => "abcde",
			:specimen_id => self.sample_id,
			:tests => ["TRIG"],
			:priority => "R"
		}

		patient = Patient.new({:sequence_number => "0", :patient_id => "abcde"})
		
		order = Order.new({:sequence_number => patient.sequence_number, :specimen_id => variables[:specimen_id], :tests => variables[:tests], :priority => variables[:priority]})

		return patient.build_response + order.build_response
		
	end

end