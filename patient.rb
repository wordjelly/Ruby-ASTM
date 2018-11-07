class Patient
	attr_accessor :sequence_number
	attr_accessor :orders
	def initialize(line)
		self.sequence_number = line.fields[1].to_i
		self.orders = []
	end
end