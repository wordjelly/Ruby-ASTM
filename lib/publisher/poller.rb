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
  	URINE = "URINE"
  	REQUISITIONS_SORTED_SET = "requisitions_sorted_set"
  	REQUISITIONS_HASH = "requisitions_hash"
	POLL_STATUS_KEY = "ruby_astm_lis_poller"
	LAST_REQUEST_AT = "last_request_at"
	LAST_REQUEST_STATUS = "last_request_status"
	RUNNING = "running"
	COMPLETED = "completed"

	def initialize(mpg=nil)
		$redis = Redis.new
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

  	def build_tests_hash(record)
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
	    unless record[28].blank?
	      tube_ids[EDTA] = record[28].to_s
	      tests_hash[EDTA + ":" + record[28].to_s] = []
	    end

	    unless record[29].blank?
	      tube_ids[SERUM] = record[29].to_s
	      tests_hash[SERUM + ":" + record[29].to_s] = []
	    end

	    unless record[30].blank?
	      tube_ids[PLASMA] = record[30].to_s
	      tests_hash[PLASMA + ":" + record[30].to_s] = []
	    end

	    unless record[31].blank?
	      tube_ids[FLUORIDE] = record[31].to_s
	      tests_hash[FLUORIDE + ":" + record[31].to_s] = []
	    end

	    unless record[32].blank?
	      tube_ids[URINE] = record[32].to_s
	      tests_hash[URINE + ":" + record[32].to_s] = []
	    end

	    unless record[33].blank?
	      tube_ids[ESR] = record[33].to_s
	      tests_hash[ESR + ":" + record[33].to_s] = []
	    end


	    tests = record[8].split(",")
	    tests.each do |test|
	      ## use the inverted mappings to 
	      if machine_code = $inverted_mappings[test]
	        ## now get its tube type
	        ## mappings have to match the tubes defined in this file.
	        tube = $mappings[machine_code]["TUBE"]
	        ## now find the tests_hash which has this tube.
	        ## and the machine code to its array.
	        ## so how to find this.
	        tube_key = tests_hash.keys.select{|c| c=~/#{tube}/ }[0] 
	        tests_hash[tube_key] << machine_code   
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
	def merge_with_requisitions_hash(epoch,tests)
	    ## so we basically now add this to the epoch ?
	    ## or a sorted set ?
	    ## key -> TUBE:specimen_id
	    ## value -> array of tests as json
	    ## score -> time.
	    $redis.multi do |multi|
	      $redis.zadd REQUISITIONS_SORTED_SET, epoch, JSON.generate(tests)
	      tests.keys.each do |tube_barcode|
	        $redis.hset REQUISITIONS_HASH, tube_barcode, JSON.generate(tests[tube_barcode])
	      end  
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
  	def update(data)

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
				update(patient_results)
				patients_to_process = $redis.llen("patients") > 0
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
	def poll_LIS_for_requisition

  	end

  	def poll
  		pre_poll_LIS
  		poll_LIS_for_requisition
  		update_LIS
  		post_poll_LIS
  	end

end