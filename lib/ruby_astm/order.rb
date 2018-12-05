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

	def initialize(args)
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
			self.tests = args[:tests]
			self.date_time = args[:date_time]
			self.priority = args[:priority]
			self.action_code = args[:action_code]
		end
		self.results = {}
	end

	def build_response
		
		raise "provide a sequence number" if self.sequence_number.blank?
		raise "provide a specimen id" if self.id.blank?
		#raise "provide a list of tests" if self.tests.blank?
		raise "provide a test priority" if self.priority.blank?
		
		if self.specimen_type.blank?
			#puts "no specimen type has been provided, sending SERUM"
		end

		"O|#{self.sequence_number}|#{self.id}^01||^^^#{self.tests.join('`^^^')}|#{self.priority}||#{Time.now.strftime("%Y%m%d%H%M%S")}||||N||||#{self.specimen_type || 'SERUM'}\r"
	end	

end