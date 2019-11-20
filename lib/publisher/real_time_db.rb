require 'rest-firebase'
require "resolv-replace"
class RealTimeDb

	SITE_URL = ENV["FIREBASE_SITE"]
	SECRET = ENV["FIREBASE_SECRET"]
	attr_accessor :connection
	attr_accessor :work_allotment_hash
	WORK_TYPES = {
		"IMMUNO" => "",
		"BIOCHEM" => "",
		"BIOCHEM-EXL" => "",
		"BIOCHEM-ELECTROLYTE" => "",
		"HEMAT" => "",
		"URINE" => "",
		"OUTSOURCE" => ""
	}

	## first i email myself the site and secret
	## then we proceed.

	## @param[Hash] work_allotment_hash :
	## key => one of the work types
	## value => name of a worker
	def initialize(work_allotment_hash)
		self.connection = RestFirebase.new :site => SITE_URL,
                     :secret => SECRET
        puts "initialized"
        self.work_allotment_hash = work_allotment_hash || WORK_TYPES
	end

	def open_event_stream
		es = self.connection.event_source('users/tom')
		es.onopen   { |sock| p sock } # Called when connected
		es.onmessage{ |event, data, sock| p event, data } # Called for each message
		es.onerror  { |error, sock| p error } # Called whenever there's an error
		# Extra: If we return true in onreconnect callback, it would automatically
		#        reconnect the node for us if disconnected.
		@reconnect = true

		es.onreconnect{ |error, sock| p error; @reconnect }

		# Start making the request
		es.start

		self.connection.wait
	end




	## we pass the real_time_data instance into the 

	def assign_test(barcode,tests,mappings)
		## so do we get the name of the worker.
		inverted_mappings = {}
		mappings.keys.each do |machine_code|
			lis_code = mappings[machine_code][LIS_CODE]
			inverted_mappings[lis_code] = mappings[machine_code]
		end
		worker_hash = {}
		tests.each do |lis_code|
			worker_name = "NO_ONE"
			unless inverted_mappings[lis_code].blank?
				test_type = inverted_mappings[lis_code]["TYPE"]
				worker_name = self.work_allotment_hash[test_type]
			end
			worker_hash[worker_name] ||= []
			worker_hash[worker_name] << lis_code
		end
		worker_hash.keys.each do |worker_name|
			#self.connection.post("lab/work/#{worker_name}", :tests => worker_hash[worker_name], :barcode => barcode, :timestamp => Time.now.to_i)
		end
	end
	
end