class Header
	attr_accessor :machine_name
	attr_accessor :patients
	attr_accessor :queries
	attr_accessor :response_sent
	attr_accessor :protocol

	def is_astm?
		self.protocol == "ASTM"
	end		

	def is_hl7?
		self.protocol == "HL7"
	end


	def set_protocol(args)
		self.protocol = "ASTM"
	end	

	def initialize(args)
		self.patients = []
		self.queries = []
		self.response_sent = false
		if line = args[:line]
			set_machine_name(args)
			set_protocol(args)
		else
			super
		end
	end

	def set_machine_name(args)
		if line = args[:line]
			unless line.fields[4].empty?
				fields = line.fields[4].split(/\^/)
				self.machine_name = fields[0].strip
			end
		end
	end

	## pushes each patient into a redis list called "patients"
	def commit
		self.patients.map{|patient| $redis.lpush("patients",patient.to_json)}
		#puts JSON.pretty_generate(JSON.parse(self.to_json))
	end

	## used to respond to queries.
	## @return[String] response_to_query : response to the header query.
	def build_responses
		responses = self.queries.map {|query|
			header_response = "1H|\`^&||||||||||P|E 1394-97|#{Time.now.strftime("%Y%m%d%H%M%S")}\r"
			query.response = header_response + query.build_response
			query.response
		}
		responses
	end

	def to_json
        hash = {}
        self.instance_variables.each do |x|
            hash[x] = self.instance_variable_get x
        end
        return hash.to_json
    end

end