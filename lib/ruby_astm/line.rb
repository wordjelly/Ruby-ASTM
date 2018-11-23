class Line

	TYPES = {
		"H" => "Header",
		"P" => "Patient",
		"Q" => "Query",
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
		#puts "detecting line type: #{self.text}"
		line_type = self.fields[0]
		line_type.scan(/(?<ltype>[A-Z])/) { |ltype| 
			#puts "got ltype as: #{ltype[0]}"
			#puts Line::TYPES.to_s
			if Line::TYPES[ltype[0]]
				self.type = Line::TYPES[ltype[0]]
				#puts "assigning type as: #{self.type}"
			end
		}		
	
=begin
			if self.fields[0][1..-1] =~/#{type}/
				puts "got type: #{Line::TYPES[type]}"
				self.type = Line::TYPES[type]
				break
			end
=end
		
	end

	

end