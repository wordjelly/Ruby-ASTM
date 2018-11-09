class Result
	attr_accessor :name
	attr_accessor :value
	attr_accessor :units
	attr_accessor :flags
	attr_accessor :timestamp
	attr_accessor :reference_ranges
	attr_accessor :dilution

	def initialize(line)
		line.fields[2].scan(/\^{4}(?<name>[A-Za-z0-9]+)\^(?<dilution>\d+)/) { |name,dilution|  
			self.name = name
			self.dilution = dilution
		}
		self.value = line.fields[3].strip
		self.reference_ranges = line.fields[5].strip
		self.flags = line.fields[6].strip 
		line.fields[12].strip.scan(/(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})(?<hours>\d{2})(?<minutes>\d{2})(?<seconds>\d{2})/) {|year,month,day,hours,minutes,seconds|
			self.timestamp = Time.new(year,month,day,hours,minutes,seconds)
		}
	end

end