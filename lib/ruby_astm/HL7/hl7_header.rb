require "ruby_astm/header"
class Hl7Header < Header
	## overriding from header.
	attr_accessor :date_time
	attr_accessor :message_type
	attr_accessor :message_control_id

	def set_protocol(args)
		self.protocol = "HL7"
	end	

	def initialize(args)
		super
		set_machine_name(args)
		set_date_time(args)
		set_message_type(args)
		set_message_control_id(args)
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

	################################################################################
	##
	##
	## METHODS FOR generating the acknowledgement to an HL7 Message
	##
	##
	################################################################################

	def seperator
		"|"
	end

	def header
		"MSH"
	end

	def field_seperators
		"^~\\&"
	end

	def sending_application_name
		"Pathofast_LIS"
	end

	def sending_facility_name
		"Pathofast"
	end

	def sending_date_time
		Time.now.strftime("%Y%m%d%H%M%S")		
	end

	def ack_message
		"ACK"
	end

	def nack_message
		"NACK"
	end

	def hl7_version
		"2.4"
	end

	def generate_ack_success_response
		
		ack_msg = ""
		ack_msg += header + seperator
		ack_msg += field_seperators + seperator
		ack_msg += sending_application_name + seperator
		ack_msg += sending_facility_name + seperator
		ack_msg += seperator
		ack_msg += seperator
		ack_msg += sending_date_time + seperator
		ack_msg += seperator
		ack_msg += ack_msg + seperator
		ack_msg += self.message_control_id + seperator
		ack_msg += seperator
		ack_msg += hl7_version + seperator
		ack_msg += seperator
		ack_msg += seperator
		ack_msg += seperator
		ack_msg += seperator
		ack_msg += seperator
		ack_msg += seperator
		ack_msg += seperator
		ack_msg += "AA" + seperator
		ack_msg += sending_date_time + seperator
		ack_msg

	end

	def generate_ack_failure_response

	end

end		