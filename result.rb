class Result
	attr_accessor :name
	attr_accessor :value
	attr_accessor :units
	attr_accessor :flags
	attr_accessor :timestamp
	def initialize(line)
		line.fields[2].scan(/\^{4}(?<name>[A-Za-z0-9]+)\^(?<dilution>\d+)/) { |name,dilution|  
			self.name = name
			self.dilution = dilution
		}
		self.value = line.fields[3]
		self.
	end
end