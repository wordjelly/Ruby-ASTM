require 'rufus-scheduler'
require 'time'
require 'redis'

class Poller
	#############################################################################3
	##
	##
	## require the file that implements the Adapter class.
	##
	##
	##############################################################################
	EDTA = "EDTA"
  	SERUM = "SERUM"
  	PLASMA = "PLASMA"
  	FLUORIDE = "FLUORIDE"
  	ESR = "ESR"
  	URINE = "URINE_CONTAINER"
  	REQUISITIONS_SORTED_SET = "requisitions_sorted_set"
  	REQUISITIONS_HASH = "requisitions_hash"
	POLL_STATUS_KEY = "ruby_astm_lis_poller"
	LAST_REQUEST_AT = "last_request_at"
	LAST_REQUEST_STATUS = "last_request_status"
	RUNNING = "running"
	COMPLETED = "completed"

	def initialize(mpg=nil,real_time_db=nil)
		$redis = Redis.new
		$real_time_db = real_time_db
		## this mapping is from MACHINE CODE AS THE KEY
	    $mappings = JSON.parse(IO.read(mpg || AstmServer.default_mappings))
	    ## INVERTING THE MAPPINGS, GIVES US THE LIS CODE AS THE KEY.
	    $inverted_mappings = Hash[$mappings.values.map{|c| c = c["LIS_CODE"]}.zip($mappings.keys)]
	end

	def root_path
    	File.dirname __dir__
  	end


	def prepare_redis
		if ($redis.exists "processing") == 0
			$redis.lpush("processing",JSON.generate([]))
		end
	end

	def pre_poll_LIS
	    previous_requisition_request_status = nil
	    
	    if previous_requisition_request_status = $redis.get(POLL_STATUS_KEY)

	      last_request_at = previous_requisition_request_status[LAST_REQUEST_AT]
	      
	      last_request_status = previous_requisition_request_status[LAST_REQUEST_STATUS]  
	    end


	    running_time = Time.now.to_i

	    $redis.watch(POLL_STATUS_KEY) do

	      if $redis.get(POLL_STATUS_KEY) == previous_requisition_request_status
	        if ((last_request_status != RUNNING) || ((Time.now.to_i - last_request_at) > 600))
	          $redis.multi do |multi|
	            multi.set(POLL_STATUS_KEY, JSON.generate({LAST_REQUEST_STATUS => RUNNING, LAST_REQUEST_AT => running_time}))
	          end
	          AstmServer.log("pre poll lis status set to running")
	        end
	      else
	      	AstmServer.log("pre poll lis status check interrupted by another client, so exiting here")
	        $redis.unwatch
	        return
	      end
	    end
	end

	## uses redis CAS to ensure that two requests don't overlap.
	## will update to the requisitions hash the specimen id -> and the 
	## now lets test this.
	## how to stub it out ?
	## first we call it direct.
	def post_poll_LIS
    
	    requisition_status = JSON.parse($redis.get(POLL_STATUS_KEY))
	    
	    if (requisition_status[LAST_REQUEST_STATUS] == RUNNING)

	      $redis.watch(POLL_STATUS_KEY) do

	        if $redis.get(POLL_STATUS_KEY) == JSON.generate(requisition_status)

	          $redis.multi do |multi|
	            multi.set(POLL_STATUS_KEY,JSON.generate({LAST_REQUEST_STATUS => COMPLETED, LAST_REQUEST_AT => requisition_status[LAST_REQUEST_AT]}))
	          end
	          AstmServer.log("post poll LIS status set to completed")
	        else
	          AstmServer.log("post poll LIS was was interrupted by another client , so exited this thread")
	          $redis.unwatch(POLL_STATUS_KEY)
	          return
	        end

	      end

	    else
	    	AstmServer.log("post poll LIS was not in running state")
	    end

  	end	

  	def assign_tube(component_machine_code,tests_hash,tube_type)
  		tube_key = nil
        unless tests_hash.keys.select{|c| c=~/#{tube_type}/ }.blank?
        	tube_key = tests_hash.keys.select{|c| c=~/#{tube_type}/ }[0] 
        	tests_hash[tube_key] << component_machine_code 
        end
  	end

  	## first we have to test the packages.

  	def determine_tube(component_machine_code,tests_hash)
  		res = $mappings[component_machine_code]["TUBE"]
        if res.is_a? Array
        	res.each do |tube|
        		assign_tube(component_machine_code,tests_hash,tube)
        	end
        elsif res.is_a? String
       		assign_tube(component_machine_code,tests_hash,res)	
        end
  	end

  	def build_tests_hash(record)
  		#puts "Record is ---------------------------------------------"
  		#puts record
	    tests_hash = {}
	    ## key -> TUBE_NAME : eg: EDTA
	    ## value -> its barcode id.
	    tube_ids = {}
	    ## assign.
	    ## lavender -> index 28
	    ## serum -> index 29
	    ## plasm -> index 30
	    ## fluoride -> index 31
	    ## urine -> index 32
	    ## esr -> index 33
	    unless record[24].blank?
	      tube_ids[EDTA] = record[24].to_s
	      tests_hash[EDTA + ":" + record[24].to_s] = []
	    end

	    unless record[25].blank?
	      tube_ids[SERUM] = record[25].to_s
	      tests_hash[SERUM + ":" + record[25].to_s] = []
	    end

	    unless record[26].blank?
	      tube_ids[PLASMA] = record[26].to_s
	      tests_hash[PLASMA + ":" + record[26].to_s] = []
	    end

	    unless record[27].blank?
	      tube_ids[FLUORIDE] = record[27].to_s
	      tests_hash[FLUORIDE + ":" + record[27].to_s] = []
	    end

	    unless record[28].blank?
	      tube_ids[URINE] = record[28].to_s
	      tests_hash[URINE + ":" + record[28].to_s] = []
	    end

	    unless record[29].blank?
	      tube_ids[ESR] = record[29].to_s
	      tests_hash[ESR + ":" + record[29].to_s] = []
	    end

	    tests = record[7].split(",").compact

	    ## these test names are whatever are coming 
	    ## from 

	   
	    return tests_hash if tests_hash.empty?

	    #puts "inverted mappings are:"
	    #puts $inverted_mappings.keys.to_s
	    #exit(1)
	    #exit(1)

	    tests.each do |test|
	      ## use the inverted mappings to 
	      if machine_code = $inverted_mappings[test]
	      	puts "machine code is: #{machine_code}"
	        ## now get its tube type
	        ## mappings have to match the tubes defined in this file.
	        
	        if package_components = $mappings[machine_code]["PACKAGE_COMPONENTS"]

	        	puts package_components.to_s

	        	package_components.each do |component|
	        		#puts "doing component: #{component}"
	        		## these are the machine codes.
	        		## so to get the tube, you have to get it from the inverted mappings.
	        		## cant get directly like this.
	        		#puts "inverted mappings"
	        		#puts $inverted_mappings
	        		component_machine_code = $inverted_mappings[component]
	        		if component == "UCRE"
	        			puts "component machine code: #{component_machine_code}"
	        		end
	        		## for eg plasma tube can do all the tests
	        		## so can serum
	        		## but we use the plasma tube only for some.
=begin
	        		tube = $mappings[component_machine_code]["TUBE"]
			        tube_key = nil
			        unless tests_hash.keys.select{|c| c=~/#{tube}/ }.blank?
			        	tube_key = tests_hash.keys.select{|c| c=~/#{tube}/ }[0] 
			        	tests_hash[tube_key] << component_machine_code 
			        end   
=end
					determine_tube(component_machine_code,tests_hash)

	        	end

	        else
	        	## here also it is the same problem.
	        	## this can be sorted out by using the array of the tube.
	        	tube = $mappings[machine_code]["TUBE"]
		        tube_key = nil
		        unless tests_hash.keys.select{|c| c=~/#{tube}/ }.blank?
		        	tube_key = tests_hash.keys.select{|c| c=~/#{tube}/ }[0] 
		        	tests_hash[tube_key] << machine_code 
		        end   
	        end
	       
	        

	      else
	        AstmServer.log("ERROR: Test: #{test} does not have an LIS code")
	      end 
	    end
	    AstmServer.log("tests hash generated")
	    AstmServer.log(JSON.generate(tests_hash))
	    tests_hash
	end

	## @param[Integer] epoch : the epoch at which these tests were requested.
	## @param[Hash] tests : {"EDTA:barcode" => [MCV,MCH,MCHC...]}
	## the test codes here are the lis_codes
	## so we need the inverted mappings for this
	def merge_with_requisitions_hash(epoch,tests)
	    ## so we basically now add this to the epoch ?
	    ## or a sorted set ?
	    ## key -> TUBE:specimen_id
	    ## value -> array of tests as json
	    ## score -> time.
	    $redis.multi do |multi|
	      $redis.zadd REQUISITIONS_SORTED_SET, epoch, JSON.generate(tests)
	      tests.keys.each do |tube_barcode|
	      	## in this hash we want the key to be only the specimen id.
	      	## and not prefixed by the tube type like FLUORIDE etc.
	      	## i don't want the individual tests,
	      	## i want the report name.
	      	## prefixed to it.
	      	tube_barcode.scan(/:(?<barcode>.*)$/) { |barcode|  
	      		$redis.hset REQUISITIONS_HASH, barcode, JSON.generate(tests[tube_barcode])
	      		$real_time_db.assign_test(barcode,tests[tube_barcode],$mappings) unless $real_time_db.blank?
	      	}
	      end  
	    end
	end

	def default_checkpoint
		(Time.now - 1.days).to_i*1000
	end

	def get_checkpoint
		latest_two_entries = $redis.zrange Poller::REQUISITIONS_SORTED_SET, -2, -1, {withscores: true}
		unless latest_two_entries.blank?
    		last_entry = latest_two_entries[-1][1].to_i
    		#one_year_back = Time.now - 1.year
    		#one_year_back = one_year_back.to_i
    		#time_now = Time.now.to_i
    		#puts "diff is: #{time_now*1000 - one_year_back*1000}"
    		#puts "one year back is "
    		#puts "last entry is: #{last_entry}"
    		#puts "last entry - Time.now is :#{Time.now.to_i*1000 - last_entry}"
    		#puts "default checkpoint is :#{default_checkpoint}"
    		#last_entry
    		#default_checkpoint
    		if (((Time.now.to_i)*1000) - last_entry) >= 86400*1000
    			puts "diff is too great"
    			default_checkpoint
    		else
    			puts "taking the last entry"
    			last_entry
    		end 
    	else
    		default_checkpoint
		end
	end

  	## @param[String] json_response : contains the response from the LIS
  	## it should be the jsonified version of a hash that is structured as follows: 
=begin
  	{
    	"epoch" => [
      	[index_8 : list_of_LIS_TEST_CODES_seperated_by_commas, index 28 => lavender, index 29 => serum, index 30 => plasma, index 31 => fluoride, index 32 => urine, index 33 => esr]
  	}
=end
  	## @return[nil]
  	def process_LIS_response(json_response)
	    lab_results = JSON.parse(json_response)
	    AstmServer.log("requisitions downloaded from LIS")
	    AstmServer.log(JSON.generate(lab_results))
	    lab_results.keys.each do |epoch|
	      merge_with_requisitions_hash(epoch,build_tests_hash(lab_results[epoch][0]))
	    end
  	end

  	## override to define how the data is updated.
  	## expected to return Boolean value, depending on whether the update was successfull or not.
  	def update(data)
  		true
  	end

	##@param[Array] data : array of objects.
	##@return[Boolean] true/false : depending on whether it was successfully updated or not.
	## recommended structure for data.
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
  	## pretty simple, if the value is not already there it will be updated, otherwise it won't be.
	def update_LIS
		prepare_redis
		patients_to_process = $redis.llen("patients") > 0
		while patients_to_process == true
			if patient_results = $redis.rpoplpush("patients","processing")
				patient_results = JSON.parse(patient_results)
				## do this before the update, so that we don't go into an endless loop if the current update fails.
				patients_to_process = $redis.llen("patients") > 0
				unless update(patient_results)
					$redis.lpush("patients",JSON.generate(patient_results))
				end
			else
				patients_to_process = false
			end
		end
	end

	## this method should be overriden.
  	## will poll the lis, and store locally, in a redis sorted set the following:
  	## key => specimen_id
  	## value => tests designated for that specimen.
  	## score => time of requisition of that specimen.
  	## name of the sorted set can be defined in the class that inherits from adapter, or will default to "requisitions"
  	## when a query is sent from any laboratory equipment to the local ASTMServer, it will query the redis sorted set, for the test information.
  	## so this poller basically constantly replicates the cloud based test information to the local server.
	def poll_LIS_for_requisition(to_epoch=nil)

  	end

  	def poll
  		pre_poll_LIS
  		poll_LIS_for_requisition
  		update_LIS
  		post_poll_LIS
  	end

end