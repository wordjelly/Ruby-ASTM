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

	POLL_STATUS_KEY = "ruby_astm_lis_poller"
	LAST_REQUEST_AT = "last_request_at"
	LAST_REQUEST_STATUS = "last_request_status"
	RUNNING = "running"
	COMPLETED = "completed"

	def initialize
		$redis = Redis.new
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

  	def poll_LIS_for_requisition
  		pre_poll_LIS
  		google_lint = Google_Lab_Interface.new
		google_lint.poll_LIS_for_requisition
		post_poll_LIS
  	end


	def poll_lis
=begin
		scheduler = Rufus::Scheduler.new
		scheduler.every '3s' do
			prepare_redis
			patients_to_process = $redis.llen("patients") > 0
			puts "patients to process is: #{patients_to_process}"
			while patients_to_process == true
				if patient_results = $redis.rpoplpush("patients","processing")
					patient_results = JSON.parse(patient_results)
					google_lint = Google_Lab_Interface.new
					google_lint.update_LIS(patient_results["@orders"])
					google_lint.poll_LIS
					patients_to_process = $redis.llen("patients") > 0
				else
					patients_to_process = false
				end
			end
			##
			puts "polling LIS for new results to replicate to the local server."
			google_lint = Google_Lab_Interface.new
			google_lint.poll_LIS
		end
		scheduler.join
=end
		google_lint = Google_Lab_Interface.new
		google_lint.poll_LIS
	end

end