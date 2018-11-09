class Order
	## => patient id.
	attr_accessor :id
	## => key : result name.
	## => value : result object
	attr_accessor :results
	def initialize(line)
		line.fields[3].strip.scan(/(?<tube_rack>\d+\^)+(?<patient_id>.+)\^/) { |tube_rack,patient_id|  self.id = patient_id.strip}
		self.results = {}
	end
end