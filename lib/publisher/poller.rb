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

	def initialize
		$redis = Redis.new
	end

	def prepare_redis
		if ($redis.exists "processing") == 0
			$redis.lpush("processing",JSON.generate([]))
		end
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