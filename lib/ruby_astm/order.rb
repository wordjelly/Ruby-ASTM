class Order
	## => patient id.
	## => should match the specimen id that comes into the query.
	## index (2)
	attr_accessor :id
	
	## this should be same as the one for patient.
	## index (1)
	attr_accessor :sequence_number
	
	## => key : result name.
	## => value : result object
	attr_accessor :results
	
	## the list of tests that need to be performed.
	## each should be prefixed by three carets
	## index (4)
	attr_accessor :tests
	## the specimen type.

	## index (15)
	attr_accessor :specimen_type


	## the order type, like stat, routine etc.
	## index (5)
	attr_accessor :priority

	## the date and time of collection
	## index (7)
	attr_accessor :date_time

	## action code
	## index (11)
	attr_accessor :action_code

	def set_id(args)
		if line = args[:line]
			if !line.fields[2].blank?
				line.fields[2].strip.scan(/(?<specimen_id>[^\^]+)/) { |specimen_id|
					self.id ||= specimen_id[0]
				}
			elsif !line.fields[3].blank?
				## for the sysmex xn-550 this is the regex.
				line.fields[3].strip.scan(/(?<tube_rack>\d+\^)+(?<patient_id>.+)\^/) { |tube_rack,patient_id|  self.id = patient_id.strip} 
			end
		else
			self.id = args[:specimen_id]
		end
	end

	def set_sequence_number(args)
		self.sequence_number = args[:sequence_number]
	end

	def set_tests(args)
		self.tests = args[:tests]
	end

	def set_specimen_type(args)
		self.specimen_type = args[:specimen_type]
	end

	def set_date_time(args)		
		self.date_time = args[:date_time]
	end

	def set_priority(args)
		self.priority = args[:priority]
	end

	def set_action_Code(args)
		self.action_code = args[:args]
	end

	def initialize(args={})
		puts "------------ INITIALIZING ORDER -------------- "
		set_id(args)
		set_priority(args)
		set_sequence_number(args)
		set_tests(args)
		set_specimen_type(args)
		set_date_time(args)
		set_priority(args)
		set_action_Code(args)
=begin		
		if args[:line]
			line = args[:line]
			if !line.fields[2].strip.blank?
				line.fields[2].strip.scan(/(?<specimen_id>[^\^]+)/) { |specimen_id|
					self.id ||= specimen_id
				}
			elsif !line.fields[3].strip.blank?
				## for the sysmex xn-550 this is the regex.
				line.fields[3].strip.scan(/(?<tube_rack>\d+\^)+(?<patient_id>.+)\^/) { |tube_rack,patient_id|  self.id = patient_id.strip}
			end
		else
			self.sequence_number = args[:sequence_number]
			self.tests = args[:tests]
			self.id = args[:specimen_id]
			self.specimen_type = args[:specimen_type]
			self.date_time = args[:date_time]
			self.priority = args[:priority]
			self.action_code = args[:action_code]
		end
=end
		self.results = {}
	end

	def build_response(options)
		
		raise "provide a sequence number" if self.sequence_number.blank?
		raise "provide a specimen id" if self.id.blank?
		#raise "provide a list of tests" if self.tests.blank?
		raise "provide a test priority" if self.priority.blank?
		
		if self.specimen_type.blank?
			#puts "no specimen type has been provided, sending SERUM"
		end

		if (options[:machine_name] && (options[:machine_name] == "cobas-e411"))
			

			## remove all the non number tests, as these are not to be run on the roche system, and cause the roche machine to clam up totally if non recognized/alphabetic tests are sent to it in the response.


			self.tests = self.tests.select{|c| c =~ /[0-9]+/}

			self.tests = self.tests.map{|c| c = "^^^" + c + "^1"}
			# ^^0000000387^587^0^2^^S1^SC
			id_string = options[:sequence_number] + "^" + options[:carrier_number] + "^" + options[:position_number] + "^^" + options[:sample_type] + "^" + options[:container_type]

			
			"O|1|#{self.id.to_s}|#{id_string}|#{tests.join('\\')}|#{self.priority}||#{Time.now.strftime("%Y%m%d%H%M%S")}||||A||||1||||||||||O\r"

		else

			tests = self.tests.select{|c| c =~ /[A-Z]+/}

			"O|#{self.sequence_number}|#{self.id}|#{Time.now.to_i.to_s}|^^^#{tests.join('`^^^')}|#{self.priority}||#{Time.now.strftime("%Y%m%d%H%M%S")}||||N||||#{self.specimen_type || 'SERUM'}\r"
	
		end

		## for urine it does not get the report name.
		## so let me do one entry for urine and hemogram.

	end	

	def results_values_hash
		values_hash = {}
		self.results.keys.each do |k|
			values_hash[k] = self.results[k].value
		end
		values_hash
	end

end