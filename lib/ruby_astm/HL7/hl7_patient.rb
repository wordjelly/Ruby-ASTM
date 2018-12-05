require "ruby_astm/patient"
class Hl7Patient < Patient
	def set_sequence_number(args)
		
	end

	def set_patient_id(args)
		if line = args[:line]
			unless line.fields[3].blank?
				self.patient_id = line.fields[3].strip
			end
		end
	end
end