class Patient
	
	## sequence number can only be from 0 -- 9.
	attr_accessor :sequence_number
	attr_accessor :patient_id
	attr_accessor :orders
	
	def set_sequence_number(args)
		if line = args[:line]
			self.sequence_number = line.fields[-1].to_i
		else
			self.sequence_number = args[:sequence_number]
		end
	end

	def set_patient_id(args)
		self.patient_id = args[:patient_id]
	end

	def initialize(args={})
		set_sequence_number(args)
		set_patient_id(args)
		self.orders = []
	end

	## patient id.
	def build_response(options)
		if (options[:machine_name] && (options[:machine_name] == "cobas-e411"))
			"P|1\r"
		else
			"P|#{self.sequence_number}|#{self.patient_id}|||||||||||||||\r"
		end
	end

	def to_json
        hash = {}
        self.instance_variables.each do |x|
            hash[x] = self.instance_variable_get x
        end
        return hash.to_json
    end

end