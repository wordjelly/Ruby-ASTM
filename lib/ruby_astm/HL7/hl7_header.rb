require "ruby_astm/header"
class Hl7Header < Header
	## overriding from header.
	attr_accessor :date_time
	attr_accessor :message_type
	attr_accessor :message_control_id

	def initialize(args)
		super.tap do |r|
			set_machine_name(args)
			set_date_time(args)
			set_message_type(args)
			set_message_control_id(args)
		end
	end

	def set_machine_name(args)
		if line = args[:line]
			unless line.fields[2].blank?
				self.machine_name = line.fields[2]
			end
		end
	end

	def set_date_time(args)
		if line = args[:line]
			unless line.fields[7].blank?
				self.date_time = line.fields[7]
			end
		end
	end	

	def set_message_type(args)
		if line = args[:line]
			unless line.fields[8].blank?
				line.fields[8].strip.scan(/(?<message_type>[A-Z]+)\^/) { |message_type|  self.message_type = message_type[0] }
			end
		end
	end

	def set_message_control_id(args)
		if line = args[:line]
			unless line.fields[9].blank?
				self.message_control_id = line.fields[9]
			end
		end
	end

	def generate_ack_success_response
		
	end

	def generate_ack_failure_response

	end

end		