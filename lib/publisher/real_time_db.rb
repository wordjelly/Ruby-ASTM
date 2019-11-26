require 'rest-firebase'
require "resolv-replace"
require "jwt"
require "net/http"

RestFirebase.class_eval do 
	def query
    	{:access_token => auth}
  	end
end

class RealTimeDb

	SITE_URL = ENV["FIREBASE_SITE"]
	SECRET = ENV["FIREBASE_SECRET"]
	ENDPOINT = "pathofast"
	ACCESSION_DONE = "ACCESSION_DONE"
	PROCESSING = "PROCESSING"
	

	attr_accessor :connection
	attr_accessor :work_allotment_hash
	attr_accessor :private_key_hash
	attr_accessor :expires_at

	WORK_TYPES = {
		"IMMUNO" => "",
		"BIOCHEM" => "",
		"BIOCHEM-EXL" => "",
		"BIOCHEM-ELECTROLYTE" => "",
		"HEMAT" => "",
		"URINE" => "",
		"OUTSOURCE" => ""
	}


	def get_jwt
		puts Base64.encode64(JSON.generate(self.private_key_hash))
		# Get your service account's email address and private key from the JSON key file
		$service_account_email = self.private_key_hash["client_email"]
		$private_key = OpenSSL::PKey::RSA.new self.private_key_hash["private_key"]
		  now_seconds = Time.now.to_i
		  self.expires_at = now_seconds + (60*30)
		  payload = {:iss => $service_account_email,
		             :sub => $service_account_email,
		             :aud => self.private_key_hash["token_uri"],
		             :iat => now_seconds,
		             :exp => now_seconds+(60*60), # Maximum expiration time is one hour
		             :scope => 'https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/firebase.database'

		         }
		  JWT.encode payload, $private_key, "RS256"
		
	end

	def generate_access_token
	  uri = URI.parse(self.private_key_hash["token_uri"])
	  https = Net::HTTP.new(uri.host, uri.port)
	  https.use_ssl = true
	  req = Net::HTTP::Post.new(uri.path)
	  req['Cache-Control'] = "no-store"
	  req.set_form_data({
	    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
	    assertion: get_jwt
	  })

	  resp = JSON.parse(https.request(req).body)
	  puts "response is:"
	  puts resp.to_s
	  resp["access_token"]
	end

	## @param[Hash] work_allotment_hash :
	## key => one of the work types
	## value => name of a worker
	def initialize(work_allotment_hash,private_key_hash)
		self.private_key_hash = private_key_hash
		raise "please provide the private key hash, from firebase service account -> create private key " if private_key_hash.blank?
		self.connection = RestFirebase.new :site => SITE_URL,
                     :secret => SECRET, :auth =>generate_access_token
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

	## if the barcode exists,
	## otherwise create it.
	def barcode_exists?(barcode)
		current_time = Time.now.to_i
		if current_time > self.expires_at
			self.connection = RestFirebase.new :site => SITE_URL,
                     :secret => SECRET, :auth =>generate_access_token
		end
			self.connection.get(ENDPOINT, :orderBy => 'barcode', :equalTo => barcode)
	end

	## idea is simple
	## send the image -> to one collection, as a post
	## take it -> analyze it -> update the result
	## to another collection
	## show it in the UI.
	## knock off the earlier one.

	## we pass the real_time_data instance into the 
	def assign_test(barcode,tests,mappings)
		## so do we get the name of the worker.
		if barcode_exists?(barcode[0]).blank?

			worker_hash = {}
			tests.each do |machine_code|
				worker_name = "NO_ONE"
				
				unless mappings[machine_code].blank?
					test_type = mappings[machine_code]["TYPE"]
					worker_name = self.work_allotment_hash[test_type]

					worker_hash[worker_name] ||= []

					#puts "worker name: #{worker_name}"
					#puts "lis code: #{machine_code}"
					#puts mappings[machine_code].to_s
					worker_hash[worker_name] << mappings[machine_code]["REPORT_NAME"]
				else
					worker_hash[worker_name] ||= []
					worker_hash[worker_name] << machine_code
				end
				
				
			end

			#puts "this is the workers hash"
			#puts worker_hash.to_s
			worker_hash.keys.each do |worker_name|
				k = self.connection.post(ENDPOINT, :tests => worker_hash[worker_name].uniq, :barcode => barcode[0], :timestamp => Time.now.strftime("%b %-d %Y %I:%M %P"), :worker_name => worker_name, :status => ACCESSION_DONE, :next_step =>  PROCESSING, :combi_key => worker_name + "_pending")
				#puts k.to_s
			end
		else
			puts "this barcode: #{barcode[0]} already exists."
		end

	end
	
end