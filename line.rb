class Line

	TYPES = {
		"H" => "Header",
		"P" => "Patient",
		"Q" => "Request",
		"O" => "Order",
		"R" => "Result",
		"L" => "Terminator"
	}

	attr_accessor :text
	
	attr_accessor :fields
	
	attr_accessor :type

	########################################################
	##
	##
	## HEADER ATTRIBUTES
	##
	##
	########################################################

	
	
	## sets the types, and fields
	## we can have processing based on line.
	def initialize(args)
		self.fields = []
		raise "no text provided" unless args[:text]
		if args[:text]
			args[:text].split(/\|/).each do |field|
				self.fields << field
			end
		end
		detect_type
	end 

	def detect_type
		Line::TYPES.keys.each do |type|
			if self.fields[0][1..-1] =~/#{type}/
				self.type = Line::TYPES[type]
				break
			end
		end
	end

	

end