class Patient
	
	## sequence number can only be from 0 -- 9.
	attr_accessor :sequence_number
	attr_accessor :patient_id
	attr_accessor :orders
	
	def initialize(args)
		if args[:line]
			line = args[:line]
			self.sequence_number = line.fields[1].to_i
			self.orders = []
		else
			self.sequence_number = args[:sequence_number]
			self.patient_id = args[:patient_id]
		end
	end

	## patient id.
	def build_response
		"P|#{self.sequence_number}|#{self.patient_id}|||||||||||||||\r"
	end

	def to_json
        hash = {}
        self.instance_variables.each do |x|
            hash[x] = self.instance_variable_get x
        end
        return hash.to_json
    end

end