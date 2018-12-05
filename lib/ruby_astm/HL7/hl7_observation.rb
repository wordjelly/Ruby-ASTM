require "ruby_astm/result"
class Hl7Observation < Result
	## first we start with the name.
	def set_name(args)
		if line = args[:line]
			self.name = lookup_mapping(line.fields[3].strip)
		end
	end

	def set_value(args)
		if line = args[:line]
			self.value = line.fields[5].strip
			if transform_expression = lookup_transform(line.fields[5].strip)
				self.value = eval(transform_expression)
			end
		end
	end

	def set_flags(args)
		if line = args[:line]
			self.flags = line.fields[8].strip unless line.fields[8].blank?
		end 
	end	

	def set_units(args)
		if line = args[:line]
			self.units = line.fields[6].strip unless line.fields[6].blank?
		end
	end

	def set_timestamp(args)
		if line = args[:line]
			line.fields[19].strip.scan(/(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})(?<hours>\d{2})(?<minutes>\d{2})(?<seconds>\d{2})/) {|year,month,day,hours,minutes,seconds|
				self.timestamp = Time.new(year,month,day,hours,minutes,seconds)
			}
		end
	end

	def set_reference_ranges(args)
		if line = args[:line]
			self.reference_ranges = line.fields[7].strip unless line.fields[7].blank?
		end
	end

	def set_dilution(args)
		
	end
end
