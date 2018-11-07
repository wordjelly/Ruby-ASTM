class Order
	attr_accessor :id
	attr_accessor :results
	def initialize(line)
		self.results = {}
	end
end