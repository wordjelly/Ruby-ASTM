require 'rufus-scheduler'
require 'time'
require 'redis'


#############################################################################3
##
##
## require the file that implements the Adapter class.
##
##
##############################################################################
require '/home/bhargav/Github/ruby_astm/google_lab_interface'

scheduler = Rufus::Scheduler.new

$redis = Redis.new

def prepare_redis
	if ($redis.exists "processing") == 0
		$redis.lpush("processing",JSON.generate([]))
	end
end

scheduler.every '3s' do
	prepare_redis
	patients_to_process = $redis.llen("patients") > 0
	puts "patients to process is: #{patients_to_process}"
	while patients_to_process == true
		if patient_results = $redis.rpoplpush("patients","processing")
			patient_results = JSON.parse(patient_results)
			google_lint = Google_Lab_Interface.new
			google_lint.update_LIS(patient_results["@orders"])
			patients_to_process = $redis.llen("patients") > 0
		else
			patients_to_process = false
		end
	end
end

scheduler.join
