require "active_support/all"

module UsbModule

	mattr_accessor :usb_response_bytes

	def begin_patient_results
		">00A00013"
	end

	def request_version
		">00000080\r00"
	end

	def request_status
		">00000082\r00"
	end

	## requests the last 5 tests performed.
	## last two digits before the carriage return are 00
	## if digits are 01 : will take the 5 penultimate tests
	## if digits are 13 : will take the first 5 tests from memory.
	def request_results
		">0002009300\r00"
	end

	def interpret?
		## if the third last is a carriage return, then interpret.l

		self.usb_response_bytes[-3] == 13
	end	

	def parse_usb_response(string_data)
		string_data.bytes.to_a.each do |byte|
			self.usb_response_bytes.push(byte)
		end
		#puts "self usb response bytes:"
		#puts self.usb_response_bytes.to_s
		if interpret?
			#puts "interpret"
			self.usb_response_bytes[13..-4].each_slice(32) do |patient_record|
				bar_code = nil
				bar_code = patient_record[11..23].pack('c*').gsub(/\./,'')
				#puts "bar code: #{bar_code}"
				unless bar_code.strip.blank?
					esr = patient_record[26]
					patient = Patient.new(:orders => [Order.new(:results => [Result.new(:value => esr, :name => "ESR", :report_name => "ESR")])])
					patient = Patient.new({})
					patient.patient_id = bar_code
					patient.orders = []
					order = Order.new({})
					result = Result.new({})
					result.value = esr.to_s
					result.name = "ESR"
					result.report_name = "ESR"
					order.id = bar_code
					order.results = []
					order.results << result
					patient.orders << order
					#puts patient.orders.size
					#puts patient.orders.first.results.size
					#puts patient.orders.first.results.first.to_s
					#puts "patient to json is:"
					puts patient.to_json
					$redis.lpush("patients",patient.to_json)
				end 
			end
			self.usb_response_bytes = []	
		else
			#puts "dont interpret"		
		end

	end

end
