require 'fileutils'
require 'publisher/poller'
require 'typhoeus'

class Pf_Lab_Interface < Poller

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

	attr_accessor :lis_security_key

	## should include the https://www.xyz.com:3000
	## defaults to http://localhost:3000
	attr_accessor :server_url_with_port

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
		order["reports"].each do |report|
			report["tests"].each do |test|
				remove_barcode(test["barcode"])
				remove_barcode(test["code"])
			end			
		end
		$redis.hdel(ORDERS,order[ID])
		$redis.zrem(ORDERS_SORTED_SET,order[ID])
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

	## @param[Hash] order : order object, as a hash.
	def add_order(order)
		## this whole thing should be done in one transaction
		order[REPORTS].each do |report|
			test_machine_codes = report[TESTS].map{|c|
				$inverted_mappings[c[LIS_CODE]]
			}.compact.uniq
			report[REQUIREMENTS].each do |req|
				get_priority_category(req)[ITEMS].each do |item|
					if !item[BARCODE].blank?
						add_barcode(item[BARCODE],JSON.generate(
							{
								:order_id => order[ID],
								:machine_codes => test_machine_codes
							}
						))
					elsif !item[CODE].blank?
						add_barcode(item[CODE],JSON.generate({
								:order_id => order[ID],
								:machine_codes => test_machine_codes
							}))
					end
				end
			end
		end
		$redis.hset(ORDERS,order[ID],JSON.generate(order))
		$redis.zadd(ORDERS_SORTED_SET,Time.now.to_i,order[ID])
	end

	## start work on simple.

	def update_order(order)
		$redis.hset(ORDERS,order[ID],JSON.generate(order))
	end
			
	## @param[Hash] order : the existing order
	## @param[Hash] res : the result from the machine, pertaining to this order.
	## @return[nil]
	## @working : updates the results from res, into the order at the relevant tests inside the order.
	## $MAPPINGS -> [MACHINE_CODE => LIS_CODE]
	## $INVERTED_MAPPINGS -> [LIS_CODE => MACHINE_CODE]
	def add_test_result(order,res)
		order[REPORTS.to_sym].each do |report|
			report[TESTS.to_sym].each_with_index{|t,k|
				if t[LIS_CODE.to_sym] == $mappings[res[:name]]
					t[RESULT_RAW.to_sym] = res[:value]
				end
			}
		end
	end

	def queue_order_for_update(order)
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
		last_request[FROM_EPOCH] == last_request[SIZE]
	end
	
	def fresh_request_params(from_epoch=nil)
		params = {}
		params[TO_EPOCH] = Time.now.to_i
		params[FROM_EPOCH] = from_epoch || (params[TO_EPOCH] - DEFAULT_LOOK_BACK_IN_SECONDS)
		params[SKIP] = 0
		params
	end

	def build_request
		last_request = get_last_request
		params = nil
		if last_request.blank?
			params = fresh_request_params
		else
			if all_hits_downloaded?(last_request)
				params = fresh_request_params(last_request[:to_epoch])
			else
				params = last_request
			end 
		end
		params.merge!(lis_security_key: self.lis_security_key)
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
	end

	# since we request only a certain set of orders per request
	# we need to know if the earlier request has been completed
	# or we still need to rerequest the same time frame again.
	def request_size_completed?(response_hash)
		response_hash[SKIP].to_i + response_hash[ORDERS].size >= response_hash[SIZE]
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
	def initialize(mpg=nil,lis_security_key,server_url_with_port)
	    super(mpg)
	    self.lis_security_key = lis_security_key
	    self.server_url_with_port = (server_url_with_port || BASE_URL)
	    AstmServer.log("Initialized Lab Interface")
	end

	def poll_LIS_for_requisition
		AstmServer.log("Polling LIS at url:#{BASE_URL}")
		request = build_request
		request.on_complete do |response|
		  if response.success?
		    response_hash = JSON.parse(response.body)
		    AstmServer.log("Pathofast LIS poll response --->")
		    AstmServer.log(response_hash.to_s)
		    orders = response_hash[ORDERS]
		    orders.each do |order|
		    	add_order(order) 
		    end
		    commit_request_params_to_redis(response_hash)
		  elsif response.timed_out?
		    # aw hell no
		    # put to astm log.
		    AstmServer.log("Polling time out")
		  elsif response.code == 0
		    # Could not get an http response, something's wrong.
		    AstmServer.log(response.return_message)
		  else
		    # Received a non-successful http response.
		    AstmServer.log("HTTP request failed: " + response.code.to_s)
		  end
		end
		request.run
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
		ORDERS_TO_UPDATE_PER_CYCLE.times do |n|
			order_ids << $redis.rpop(UPDATE_QUEUE)
		end
		#puts "order ids popped"
		#puts order_ids.to_s
		orders = order_ids.map{|c|
			get_order(c)
		}.compact

		
		#puts "orders are:"
		#puts orders.to_s

		req = Typhoeus::Request.new(self.get_put_url_path, method: :put, body: {orders: orders}.to_json, params: {lis_security_key: self.lis_security_key}, headers: {Accept: 'application/json', "Content-Type".to_sym => 'application/json'})


		req.on_complete do |response|
			if response.success?
			    response_body = response.body
			    orders = JSON.parse(response.body)["orders"]
			    orders.each do |order|
			    	if order["errors"].blank?
			    	else
			    		puts "got an error for the order."
			    		## how many total error attempts to manage.
			    	end
			    end
			elsif response.timed_out?
			    AstmServer.log("got a time out")
			elsif response.code == 0
			    AstmServer.log(response.return_message)
			else
			    AstmServer.log("HTTP request failed: " + response.code.to_s)
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

	def update(data)
		data.each do |result|
			barcode = result[:id]
			results = result[:results]
			if barcode_hash = get_barcode(barcode)
				if order = get_order(barcode_hash[:order_id])
					## update the test results, and add the order to the final update hash.
					puts "order got from barcode is:"
					puts order
					machine_codes = barcode_hash[:machine_codes]
					## it has to be registered on this.
					results.each do |res|
						if machine_codes.include? res[:name]
							## so we need to update to the requisite test inside the order.
							add_test_result(order,res)	
							## commit to redis
							## and then 
						end
					end
					puts "came to queue order for update"
					queue_order_for_update(order)
				end
			else
				AstmServer.log("the barcode:#{barcode}, does not exist in the barcodes hash")
				## does not exist.
			end
		end 

		process_update_queue
		remove_old_orders
	
	end

	def get_poll_url_path
		self.server_url_with_port + POLL_ENDPOINT
	end

	def get_put_url_path
		self.server_url_with_port + PUT_ENDPOINT
	end

	def poll
      	pre_poll_LIS
      	poll_LIS_for_requisition
      	update_LIS
      	post_poll_LIS
  	end

  
end