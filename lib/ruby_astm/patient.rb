class Patient
	
	attr_accessor :sequence_number
	
	attr_accessor :orders
	
	def initialize(line)
		self.sequence_number = line.fields[1].to_i
		self.orders = []
	end

	def to_json
        hash = {}
        self.instance_variables.each do |x|
            hash[x] = self.instance_variable_get x
        end
        return hash.to_json
    end

end