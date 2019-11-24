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

	def initialize(args={})
		self.patients = []
		self.queries = []
		self.response_sent = false
		if line = args[:line]
			set_machine_name(args)
			set_protocol(args)
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
		puts JSON.pretty_generate(JSON.parse(self.to_json))
	end

	def get_header_response(options)
		if (options[:machine_name] && (options[:machine_name] == "cobas-e411"))
			"1H|\\^&|||host^1|||||cobas-e411|TSDWN^REPLY|P|1\r"
		else
			"1H|\`^&||||||||||P|E 1394-97|#{Time.now.strftime("%Y%m%d%H%M%S")}\r"
		end
	end

	## depends on the machine code.
	## if we have that or not.
	def build_one_response(options)
		puts "building one response=========="
		puts "queries are:"
		puts self.queries.size.to_s
		responses = []
		self.queries.each do |query|
			puts "doing query"
			puts query.sample_ids
			header_response = get_header_response(options)
			query.build_response(options).each do |qresponse|
				puts "qresponse is:"
				puts qresponse
				header_response += qresponse
			end
			responses << header_response
		end
		responses
	end

	## used to respond to queries.
	## @return[String] response_to_query : response to the header query.
	def build_responses
		responses = []
		self.queries.each do |query|
			header_response = "1H|\`^&||||||||||P|E 1394-97|#{Time.now.strftime("%Y%m%d%H%M%S")}\r"
			query.build_response.each do |qresponse|
				responses << (header_response + qresponse)
			end
		end
=begin
		responses = self.queries.map {|query|
			header_response = "1H|\`^&||||||||||P|E 1394-97|#{Time.now.strftime("%Y%m%d%H%M%S")}\r"
			## here the queries have multiple responses.
			query.build_response.each do |qresponse|

			end
			query.response = header_response + query.build_response
			query.response
		}
=end
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