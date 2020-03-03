require 'fileutils'
require_relative 'poller'
require_relative 'pf_download_exception'
require 'typhoeus'
require 'resolv-replace'

RestFirebase.class_eval do 
	
	attr_accessor :private_key_hash

	def query
    	{:access_token => auth}
  	end

  	def get_jwt
		puts Base64.encode64(JSON.generate(self.private_key_hash))
		# Get your service account's email address and private key from the JSON key file
		$service_account_email = self.private_key_hash["client_email"]
		$private_key = OpenSSL::PKey::RSA.new self.private_key_hash["private_key"]
		  now_seconds = Time.now.to_i
		  payload = {:iss => $service_account_email,
		             :sub => $service_account_email,
		             :aud => self.private_key_hash["token_uri"],
		             :iat => now_seconds,
		             :exp => now_seconds + 1, # Maximum expiration time is one hour
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
	  resp["access_token"]
	end

	def generate_auth opts={}
		generate_access_token
	end
 
end

class Pf_Lab_Interface < Poller

	include StreamModule

	ORDERS = "orders"
	ORDERS_SORTED_SET = "orders_sorted_set"
	BARCODES = "barcodes"
	BARCODE = "barcode"
	BASE_URL = "http://localhost:3000/"
	UPDATE_QUEUE = "update_queue"
	## will look back 12 hours if no previous request is found.
	DEFAULT_LOOK_BACK_IN_SECONDS = 12*3600
	## time to keep old orders in memory
	## 48 hours, expressed as seconds.
	DEFAULT_STORAGE_TIME_FOR_ORDERS_IN_SECONDS = 48*3600 
	## the last request that was made and what it said.
	POLL_ENDPOINT = "interfaces"
	PUT_ENDPOINT = "lis_update_orders"
	LAST_REQUEST = "last_request"
	FROM_EPOCH = "from_epoch"
	TO_EPOCH = "to_epoch"
	SIZE = "size"
	SKIP = "skip"
	ID = "id"
	REPORTS = "reports"
	TESTS = "tests"
	RESULT_RAW = "result_raw"
	CATEGORIES = "categories"
	USE_CATEGORY_FOR_LIS = "use_category_for_lis"
	LIS_CODE = "lis_code"
	REQUIREMENTS = "requirements"
	ITEMS = "items"
	CODE = "code"
	ORDERS_TO_UPDATE_PER_CYCLE = 10
	PREV_REQUEST_COMPLETED = "prev_request_completed"
	MACHINE_CODES = "machine_codes"

	attr_accessor :lis_security_key

	## should include the https://www.xyz.com:3000
	## defaults to http://localhost:3000
	attr_accessor :server_url_with_port

	attr_accessor :retry_count

	###################################################################
	##
	##
	## FLOW OF EVENTS IN THIS FILE
	##
	##
	###################################################################

	## STEP ONE:
	## PRE_POLL_LIS -> basically locks against multiple requests happening at the same time, only one request can go through at one time, this is not touched here, just inherits from poller.rb

	## poll_LIS_for_requisition -> 
	## a. calls build_request
	## b. build_request -> checks if a previous request is still open (this is done simply by checking for a redis key called LAST_REQUEST, if its found, then the previous request is open.)
	
	## if the previous request is not open, creates a fresh request by using hte function #fresh_request_params -> this basically sets a hash with two keys : from_epoch (-> now minus some default interval), to_epoch (-> now), and these are used as the params, for the the typhoeus request.
	## the response to the request is expected to contain (i.e the backend must return)
	## "orders" => an array of orders
	## "skip" => how many results it was told to skip (in the case of a fresh request it will be 0)
	## "size" => the total size of the results that were got.
	## "from_epoch" => the from_epoch sent in the request.
	## "to_epoch" => the to_epoch sent in the request.
	
	## it takes each order, and adds it to the "orders" redis hash.
	## while adding the orders, it will add individual barcodes with their tests to a "barcodes" hash.
	## the functions dealing with this are add_order, add_barcode.
	## while deciding which barcode to add, the priority_category is chosen.

	## after this is done, it will look, whether the request is complete?
	## this means that the "skip" parameter + number of results returned is equal to the total "size" of all possible results.
	## if yes, then it deletes the last_request key totally, so that next time a new request is made.
	## if not, then it commits this last_request to the last_request key.
	## only thing is that we change the skip to be the earlier skip + the number of results returned, so that the next request sent will start from


	###################################################################
	##
	##
	## UTILITY METHOD FOR THE ORDER AND BARCODE HASHES ADD AND REMOVE
	##
	##
	###################################################################
	def remove_order(order_id)
		order = get_order(order_id)
		puts "order id is:#{order_id} is"
		unless order.blank?
			puts "order not blank."
			order[:reports].each do |report|
				report[:tests].each do |test|
					remove_barcode(test[:barcode])
					remove_barcode(test[:code])
				end			
			end
			$redis.hdel(ORDERS,order_id)
			$redis.zrem(ORDERS_SORTED_SET,order_id)
		else
			puts "order is blank."
		end
	end

	def remove_barcode(barcode)
		return if barcode.blank?
		$redis.hdel(BARCODES,barcode)
	end

	## @return[Hash] the entry at the barcode, or nil.
	## key (order_id)
	## value (array of tests registered on that barcode, the names of the tests are the machine codes, and not the lis_codes)
	## this key is generated originally in add_barcode
	def get_barcode(barcode)	
		if barcode_hash = $redis.hget(BARCODES,barcode)
			JSON.parse(barcode_hash).deep_symbolize_keys
		else
			nil
		end
	end

	def get_order(order_id)
		if order_string = $redis.hget(ORDERS,order_id)
			JSON.parse(order_string).deep_symbolize_keys
		else
			nil
		end
	end

	## @param[Hash] req : the requirement hash.
	## @return[Hash] priority_category : the category which has been chosen as the top priority for the requirement.
	def get_priority_category(req)
		priority_category = req[CATEGORIES].select{|c| 
			c[USE_CATEGORY_FOR_LIS] == 1
		}
		if priority_category.blank?
			priority_category = req[CATEGORIES][0]
		else
			priority_category = priority_category[0]
		end
		priority_category
	end

	## @param[Hash]barcodes_to_tests_hash => key(barcode or code), value => test_machine_Codes
	## @param[String]code : the code or barcode
	## @param[Array]test_machine_codes : array of machine codes.
	## @return[nil]
	## @called_from : 
	def update_codes(barcodes_to_tests_hash,code,test_machine_codes)
		if barcodes_to_tests_hash[code].blank?
			barcodes_to_tests_hash[code] = test_machine_codes
		else
			barcodes_to_tests_hash[code] << test_machine_codes
			barcodes_to_tests_hash[code].flatten!
		end
	end

	## @param[Hash] order : order object, as a hash.
	def add_order(order)
		puts "came to add order with inverted mappings"
		puts JSON.pretty_generate($inverted_mappings)
		at_least_one_item_exists = false
		## a hash for the order.
		## key -> [String]barcode
		## value -> [Array]test_machine_codes
		barcodes_to_tests_hash = {}
		order[REPORTS].each do |report|
			test_machine_codes = report[TESTS].map{|c|
				puts "checking test #{c['name']} with lis code: #{c[LIS_CODE]}"
				$inverted_mappings[c[LIS_CODE]]
			}.compact.uniq
			puts "test machine codes become:"
			puts test_machine_codes
			report[REQUIREMENTS].each do |req|
				get_priority_category(req)[ITEMS].each do |item|
					if !item[BARCODE].blank?
						at_least_one_item_exists = true
						update_codes(barcodes_to_tests_hash,item[BARCODE],test_machine_codes)
					elsif !item[CODE].blank?
						at_least_one_item_exists = true
						update_codes(barcodes_to_tests_hash,item[CODE],test_machine_codes)
					end
				end
			end
		end
		
		unless at_least_one_item_exists.blank?
			barcodes_to_tests_hash.keys.each do |barcode|
				add_barcode(barcode,JSON.generate({
					:order_id => order[ID],
					:machine_codes => barcodes_to_tests_hash[barcode]
				}))
			end
			$redis.hset(ORDERS,order[ID],JSON.generate(order))
			$redis.zadd(ORDERS_SORTED_SET,Time.now.to_i,order[ID])
		end
	end

	## start work on simple.

	def update_order(order)
		$redis.hset(ORDERS,order[ID.to_sym],JSON.generate(order))
	end
			
	## @param[Hash] order : the existing order
	## @param[Hash] res : the result from the machine, pertaining to this order.
	## @return[nil]
	## @working : updates the results from res, into the order at the relevant tests inside the order.
	## $MAPPINGS -> [MACHINE_CODE => LIS_CODE]
	## $INVERTED_MAPPINGS -> [LIS_CODE => MACHINE_CODE]
	def add_test_result(order,res,lis_code)
		#puts "res is:"
		#puts res.to_s

		order[REPORTS.to_sym].each do |report|
			#puts "doing report"
			report[TESTS.to_sym].each_with_index{|t,k|
				#puts "doing test"
				#puts t.to_s
				
				puts "teh test lis code to sym is:"
				puts t[LIS_CODE.to_sym]
				puts "lis code is: #{lis_code.to_s}"
				# and here we use the res["alternate_lis_codes"]
				res.all_lis_codes.each do |lcode|
					if t[LIS_CODE.to_sym] == lcode.to_s
						puts "got equality"
						t[RESULT_RAW.to_sym] = res[:value]
						puts "set value"
						break
					end
				end
			}
		end
	end

	def queue_order_for_update(order)
		update_order(order)
		$redis.lpush(UPDATE_QUEUE,order[ID.to_sym])
	end

	def add_barcode(code,order_id)
		$redis.hset(BARCODES,code,order_id)
	end

	def get_last_request
		$redis.hgetall(LAST_REQUEST)
	end

=begin
	def delete_last_request
		$redis.del(LAST_REQUEST)
	end
=end
	def all_hits_downloaded?(last_request)
		last_request[PREV_REQUEST_COMPLETED].to_s == "true"
	end
		
	## @param[Time] from : time object 
	## @param[Time] to : time object
	def fresh_request_params(from,to)
		#puts "came to make fresh request params, with from epoch: #{from_epoch}"
		params = {}
		params[TO_EPOCH] = to.to_i
		params[FROM_EPOCH] = from.to_i
		params[SKIP] = 0
		params
	end

	## so build request should have a from and a to
	## what are the defaults ?
	## @param[Time] from : default (nil)
	## @param[Time] to : default(nil) 
	def build_request(from=nil,to=nil)
		puts "entering build request with from: #{from} and to:#{to}"
		to ||= Time.now
		from ||= to - 1.day
		last_request = get_last_request
		params = nil
		if last_request.blank?
			AstmServer.log("no last request, making fresh request")
			params = fresh_request_params(from,to)
		else
			if all_hits_downloaded?(last_request)
				AstmServer.log("last request all hits have been downloaded, going for next request.")
				if last_request[TO_EPOCH].to_i == to.to_i
					return nil
				else
					params = fresh_request_params(last_request[TO_EPOCH],to)
				end
			else
				AstmServer.log("last request all hits not downloaded.")
				params = last_request
			end 
		end
		params.merge!(lis_security_key: self.lis_security_key)
		AstmServer.log("reuqest params become: #{params}")
		AstmServer.log("sleeping")
		#sleep(10000)
		puts "params: #{params}, url #{self.get_poll_url_path}"
		Typhoeus::Request.new(self.get_poll_url_path,params: params)
	end

	## commits the request params to redis.
	## the response hash is expected to have whatever parameters were sent into it in the request.
	## so it must always return:
	## a -> how many it was told to skip (SKIP)
	## b -> from_epoch : from which epoch it was queried.
	## c -> to_epoch : to which epoch it was queried.
	def commit_request_params_to_redis(response_hash)
		$redis.hset(LAST_REQUEST,SKIP,response_hash[SKIP].to_i + response_hash[ORDERS].size.to_i)
		$redis.hset(LAST_REQUEST,SIZE,response_hash[SIZE].to_i)
		$redis.hset(LAST_REQUEST,FROM_EPOCH,response_hash[FROM_EPOCH].to_i)
		$redis.hset(LAST_REQUEST,TO_EPOCH,response_hash[TO_EPOCH].to_i)
		$redis.hset(LAST_REQUEST,PREV_REQUEST_COMPLETED,request_size_completed?(response_hash).to_s)
	end

	# since we request only a certain set of orders per request
	# we need to know if the earlier request has been completed
	# or we still need to rerequest the same time frame again.
	def request_size_completed?(response_hash)
		#puts response_hash.to_s
		response_hash[SKIP].to_i + response_hash[ORDERS].size >= response_hash[SIZE].to_i
	end
	###################################################################
	##
	##
	## ENDS.
	##
	##
	###################################################################


	###################################################################
	##
	##
	## METHODS OVERRIDDEN FROM THE BASIC POLLER.
	##
	##
	###################################################################
	## @param[String] mpg : path to mappings file. Defaults to nil.
	## @param[String] lis_security_key : the security key for the LIS organization, to be dowloaded from the organizations/show/id, endpoint in the website.
	def initialize(mpg=nil,lis_security_key,server_url_with_port,organization_id,private_key_hash)
	    super(mpg)
	    self.private_key_hash = private_key_hash
	    self.event_source = "organizations/" + organization_id
	    self.on_message_handler_function = "evented_poll_LIS_for_requisition"
	    self.lis_security_key = lis_security_key
	    
	    self.server_url_with_port = (server_url_with_port || BASE_URL)
	    self.retry_count = 0
	    ## called from stream module
	    setup_connection
	    AstmServer.log("Initialized Lab Interface")
	end

	def _trigger_lis_poll?(data)
		unless data["path"].blank?
			if data["path"] =~ /trigger_lis_poll/
				return data["data"]["epoch"].to_i
			end
			if data["path"] == "/"
				unless data["data"]["trigger_lis_poll"].blank?
					return data["data"]["trigger_lis_poll"]["epoch"].to_i
				end
			end
		end
		return
	end

	## this is triggered by whatever firebase sends
	## you put this in the callback, and let me block and see what happens.
	## we cannot watch two different endpoints ?
	## or we can ?
	## on the same endpoint -> will 
	## so it becomes a merged document.
	## and both events will fire.
	## and get triggered.
	def evented_poll_LIS_for_requisition(data)
		puts "got data it is :#{data}"
		unless data.blank?
			
			if epoch = _trigger_lis_poll?(data)
				puts "trigger lis poll epoch is:#{epoch}"
				new_poll_LIS_for_requisition(epoch)
			end
=begin
			data = data["data"].blank? ? data : data["data"]

			unless data["delete_order"].blank?
				puts "delete order is not blank"
				unless data["delete_order"]["order_id"].blank?
					puts "order id is not blank"
					puts "going to delete the completed order --------------->"
					delete_completed_order(data["delete_order"]["order_id"])
				end
			end
=end			
		else

		end
	end

	def delete_completed_order(order_id)
		remove_order(order_id)
	end

	def put_delete_order_event(order_id)
		puts self.connection.put(self.event_source,:order_id => order_id)
	end

	def test_trigger_lis_poll(epoch=nil)
		puts self.connection.put(self.event_source + "/trigger_lis_poll", :epoch => epoch)
	end

	def test_trigger_delete_order(order_id)
		puts self.connection.put(self.event_source + "/delete_order", :order_id => order_id)
	end

	def new_poll_LIS_for_requisition(to_epoch=nil)
		AstmServer.log(to_epoch.to_s)
		while true
			orders = []
			begin
				Retriable.retriable(on: PfDownloadException) do 
					self.retry_count+=1
					AstmServer.log("retrying----->")
					request = build_request(nil,to_epoch)
					puts "request is:"
					puts request.to_s
					break if request.blank?
					request.run
					response = request.response
					if response.success?
						code = response.code
						time = response.total_time
						headers = response.headers
						#AstmServer.log("successfully polled server")
						response_hash = JSON.parse(response.body)
					    #AstmServer.log("Pathofast LIS poll response --->")
					    #AstmServer.log(response_hash.to_s)
					    orders = response_hash[ORDERS]
					    orders.each do |order|
					    	add_order(order) 
					    end
					    commit_request_params_to_redis(response_hash)
					    #puts "are the orders blank: #{orders.blank?}"
					    #break if orders.blank?
					elsif response.timed_out?
						#AstmServer.log("Error polling server with code: #{code}")
						raise PfDownloadException.new("timeout")
					elsif response.code == 0
						#AstmServer.log("Error polling server with code: #{code}")
						raise PfDownloadException.new("didnt get any http response")
					else
						#AstmServer.log("Error polling server with code: #{code}")
						raise PfDownloadException.new("non 200 response")
					end
				end
			rescue => e
				puts e.to_s
				puts "raised exception-----------> breaking."
				## retryable has raised the errors again.
				break
			else
				## break only if the orders are blank.
				break if orders.blank?
			end
		end
	end

	## how it deletes the records is that when all the reports in that order are verified, then that order is cleared from all LIS receptive organizations.
	## that's the only way.
	## once I'm done with that, its only the barcodes, and then the inventory bits.

	## how it deletes records
	## so this is called in the form of a while loop.
	## how it handles the update response.
	def poll_LIS_for_requisition(to_epoch=nil)
		AstmServer.log(to_epoch.to_s)
		while true
			#puts "came back to true"
			request = build_request(nil,to_epoch)
			break if request.blank?
			request.run
			response = request.response
			code = response.code
			time = response.total_time
			headers = response.headers
			if code.to_s != "200"
				AstmServer.log("Error polling server with code: #{code}")
				break
			else
				AstmServer.log("successfully polled server")
				response_hash = JSON.parse(response.body)
			    AstmServer.log("Pathofast LIS poll response --->")
			    #AstmServer.log(response_hash.to_s)
			    orders = response_hash[ORDERS]
			    orders.each do |order|
			    	add_order(order) 
			    end
			    commit_request_params_to_redis(response_hash)
			    puts "are the orders blank: #{orders.blank?}"
			    break if orders.blank?
			end
		end
	end

=begin
data = [
      {
        :id => "ARUBA",
        :results => [
          {
            :name => "TLCparam",
            :value => 10
          },
          {
            :name => "Nparam",
            :value => 23
          },
          {
            :name => "ANCparam",
            :value => 25
          },
          {
            :name => "Lparam",
            :value => 10
          },
          {
            :name => "ALCparam",
            :value => 44
          },
          {
            :name => "Mparam",
            :value => 55
          },
          {
            :name => "AMCparam",
            :value => 22
          },
          {
            :name => "Eparam",
            :value => 222
          },
          {
            :name => "AECparam",
            :value => 21
          },
          {
            :name => "BASOparam",
            :value => 222
          },
          {
            :name => "ABCparam",
            :value => 300
          },
          {
            :name => "RBCparam",
            :value => 2.22
          },
          {
            :name => "HBparam",
            :value => 19
          },
          {
            :name => "HCTparam",
            :value => 22
          },
          {
            :name => "MCVparam",
            :value => 222
          },
          {
            :name => "MCHparam",
            :value => 21
          },
          {
            :name => "MCHCparam",
            :value => 10
          },
          {
            :name => "MCVparam",
            :value => 222
          },
          {
            :name => "RDWCVparam",
            :value => 12
          },
          {
            :name => "PCparam",
            :value => 1.22322
          }
        ]
      }
    ]
=end
	
	def process_update_queue
		#puts "came to process update queue."
		order_ids = []
		#puts $redis.lrange UPDATE_QUEUE, 0, -1
			
		## first push that to patient.
		## first create that order and add that barcode.
		## for citrate.
		## then let that get downloaded.
		## so keep on test going for that.
		## 
		## why complicate this so much.
		## just do a brpop?
		## 
		ORDERS_TO_UPDATE_PER_CYCLE.times do |n|
			order_ids << $redis.rpop(UPDATE_QUEUE)
		end
		#puts "order ids popped"
		#puts order_ids.to_s
		order_ids.compact!
		order_ids.uniq!
		orders = order_ids.map{|c|
			get_order(c)
		}.compact
		#puts orders[0].to_s
		
		#puts "orders are:"
		#puts orders.size
		#exit(1)

		req = Typhoeus::Request.new(self.get_put_url_path, method: :put, body: {orders: orders}.to_json, params: {lis_security_key: self.lis_security_key}, headers: {Accept: 'application/json', "Content-Type".to_sym => 'application/json'})


		req.on_complete do |response|
			if response.success?
			    response_body = response.body
			    orders = JSON.parse(response.body)["orders"]
			    #puts orders.to_s
			    orders.values.each do |order|
			    	#puts order.to_s
			    	if order["errors"].blank?
			    	else
			    		puts "got an error for the order."
			    		## how many total error attempts to manage.
			    	end
			    end
			    ## here we have to raise.
			elsif response.timed_out?
			    AstmServer.log("got a time out")
			    raise PfUpdateException.new("update order timed out")
			elsif response.code == 0
			    AstmServer.log(response.return_message)
			    raise PfUpdateException.new("update order response code 0")
			else
			    AstmServer.log("HTTP request failed: " + response.code.to_s)
			    raise PfUpdateException.new("update order response code non success: #{response.code}")
			end
		end

		req.run
	
	end

	## removes any orders that start from
	## now - 4 days ago
	## now - 2 days ago
	def remove_old_orders
		stale_order_ids = $redis.zrangebyscore(ORDERS_SORTED_SET,(Time.now.to_i - DEFAULT_STORAGE_TIME_FOR_ORDERS_IN_SECONDS*2).to_s, (Time.now.to_i - DEFAULT_STORAGE_TIME_FOR_ORDERS_IN_SECONDS))
		$redis.pipelined do 
			stale_order_ids.each do |order_id|
				remove_order(order_id)
			end
		end
	end

	ORDERS_KEY = "@orders"
	FAILED_UPDATES = "failed_updates"
	PATIENTS_REDIS_LIST = "patients"
	PROCESSING_REDIS_LIST = "processing"

	## this is only done on startup
	## okay so what do we 
	def reattempt_failed_updates
		$redis.scard(FAILED_UPDATES).times do 
			if patient_results = $redis.spop(FAILED_UPDATES)
				patient_results = JSON.parse(patient_results)
				begin
					Retriable.retriable(on: PfUpdateException) do 
						unless update(patient_results)
							raise PfUpdateException.new("didnt get any http response")
						end
					end
				rescue PfUpdateException => e
					AstmServer.log("reattempted and failed #{e.to_s}")
				ensure

				end
			end
		end
	end

	## we can do this.
	## args can be used to modulate exit behaviours 
	## @param[Hash] args : hash of arguments
	def update_LIS(args={})
		prepare_redis
		exit_requested = false
		Kernel.trap( "INT" ) { exit_requested = true }
		while !exit_requested
			puts "exit not requested."
			if patient_results = $redis.brpoplpush(PATIENTS_REDIS_LIST,PROCESSING_REDIS_LIST,0)
				puts "got patient results."
				patient_results = JSON.parse(patient_results)
				puts "patient results are:"
				puts JSON.pretty_generate(patient_results)
				begin
					Retriable.retriable(on: PfUpdateException) do 
						unless update(patient_results)
							raise PfUpdateException.new("didnt get any http response")
						end
					end
					exit_requested = !args[:exit_on_success].blank?
					#puts "exit requested becomes: #{exit_requested}"
				rescue => e
					$redis.sadd(FAILED_UPDATES,JSON.generate(patient_results))
					exit_requested = !args[:exit_on_failure].blank?
					puts "came to eventual rescue, exit requested is: #{exit_requested}"
					puts "error is: #{e.to_s}"
				ensure
					$redis.lpop("processing")
				end
			else
				puts "no patient results"
			end
		end
	end



	def update(data)
		puts "data is:"
		puts JSON.pretty_generate(data)
		data[ORDERS_KEY].each do |order|
			puts "order is "
			puts order
			barcode = order["id"]
			results = order["results"]
			puts "barcode is: #{barcode}, results are : #{results}"
			if results.is_a? Array
			elsif results.is_a? Hash
				results = [results]
			else
			end
			results.map!{|c| 
				c.deep_symbolize_keys!
				c
			}
			#results.deep_symbolize_keys!
			if barcode_hash = get_barcode(barcode)
				puts "barcode hash is: #{barcode_hash}"
				if order = get_order(barcode_hash[:order_id])
					puts "got order"
					## update the test results, and add the order to the final update hash.
					#puts "order got from barcode is:"
					#puts order
					machine_codes = barcode_hash[:machine_codes]
					puts "machine codes: #{machine_codes}"
					results.each do |result|
						result.keys.each do |lis_code|
							res = result[lis_code]
							add_test_result(order,res,lis_code)
						end
					end
					#puts "came to queue order for update"
					queue_order_for_update(order)
				end
			else
				AstmServer.log("the barcode:#{barcode}, does not exist in the barcodes hash")
				## does not exist.
			end
		end

		process_update_queue
		
	
	end

	def get_poll_url_path
		self.server_url_with_port + POLL_ENDPOINT
	end

	def get_put_url_path
		self.server_url_with_port + PUT_ENDPOINT
	end

	
	def _start
		evented_poll_LIS_for_requisition({"trigger_lis_poll" => {"epoch" => Time.now.to_i.to_s}})
		reattempt_failed_updates
		update_LIS
	end

	## the watcher is seperate.
	## that deals with other things.

	## this method is redundant, and no longer used
	## the whole thing is now purely evented.
	def poll
  	end


end