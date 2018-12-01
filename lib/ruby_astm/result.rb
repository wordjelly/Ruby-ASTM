class Result
	attr_accessor :name
	attr_accessor :value
	attr_accessor :units
	attr_accessor :flags
	attr_accessor :timestamp
	attr_accessor :reference_ranges
	attr_accessor :dilution

	## here will call mappings and check the result correlation
	def initialize(args)
		if args[:line]
			line = args[:line]
			line.fields[2].scan(/\^+(?<name>[A-Za-z0-9\%\#-]+)\^?(?<dilution>\d+)?/) { |name,dilution|  
				self.name = lookup_mapping(name)
				self.dilution = dilution
			}
			self.value = line.fields[3].strip
			self.reference_ranges = line.fields[5].strip
			self.flags = line.fields[6].strip 
			line.fields[12].strip.scan(/(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})(?<hours>\d{2})(?<minutes>\d{2})(?<seconds>\d{2})/) {|year,month,day,hours,minutes,seconds|
				self.timestamp = Time.new(year,month,day,hours,minutes,seconds)
			}
		else
			super
		end
	end

	## @return[String] the name defined in the mappings.json file, or the name that wqs passed in.
	def lookup_mapping(name)
		$mappings[name] ? $mappings[name]["LIS_CODE"] : name 
	end

end