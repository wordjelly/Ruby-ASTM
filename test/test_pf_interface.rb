require 'minitest/autorun'
require 'ruby_astm'

## BEFORE RUNNING THESE TESTS,
## YOU NEED TO HAVE THE PATHOFAST SERVER
## AND run the rake task: pathofast:prepare_ruby_astm_env (from the pathofast/local root folder)
## then you can run the tests below
## make sure you copy the lis security key of the pathofast organization.
## this will be the last line printed by the rake task 
class TestPfInterface < Minitest::Test
	
	HOST = "https://www.pathofast.com/"
	LIS_SECURITY_KEY="pathofast"
	ORGANIZATION_ID="5e32676b58aff600042678dd-Pathofast"
	PRIVATE_KEY_FILE="/home/root1/Desktop/Github/lab_server/private_key.json"
	#############################################
	##
	##
	## THESE TESTS ARE MEANT TO BE RUN IN CONJUCTION
	## WITH A SERVER
	## FIRST PREPARE THE SERVER BY RUNNING
	## rake pathofast:lis_setup in the Pathofast local folder
	## Then make sure the pathofast server is running at localhost:3000
	## Then run all these tests.
	##
	##
	#############################################
	### SHUTDOWN SERVER BEFORE RUNNING THIS TEST
	#####################################
	##
	##
	## REQUISITION PAGINATION
	##
	##
	#####################################
=begin
	def test_paginates_till_all_results_acquired_for_a_timestamp_ignores_order_without_barcode
		$redis = Redis.new
		$redis.del("orders")
		$redis.del("orders_sorted_set")
		$redis.del("last_request")
		$redis = Redis.new
		$redis.del("ruby_astm_log")
		k = Pf_Lab_Interface.new(nil,LIS_SECURITY_KEY,HOST,ORGANIZATION_ID,JSON.parse(IO.read("/home/bhargav/Downloads/ml-micro-analysis-b2eeef4f2d47.json")))
		t = Time.now.to_i.to_s
		puts "current time is: #{t}"
		k.test_trigger_lis_poll(t)
		data = k.connection.get("organizations/#{ORGANIZATION_ID}")
		puts "Data is : #{data}"
		k.evented_poll_LIS_for_requisition(data)
		all_orders = $redis.hgetall("orders")
		assert_equal 20, all_orders.size
	end

	#####################################
	##
	##
	## only adds order if at least one item
	## with a barcode or a code is present.
	##
	##
	#####################################
	def test_error_while_downloading_retries_thrice
		## goes into backoff retry.
		$redis = Redis.new
		$redis.del("orders")
		$redis.del("orders_sorted_set")
		$redis.del("last_request")
		$redis = Redis.new
		$redis.del("ruby_astm_log")
		k = Pf_Lab_Interface.new(nil,"dog",HOST,ORGANIZATION_ID,JSON.parse(IO.read("/home/bhargav/Downloads/ml-micro-analysis-firebase-adminsdk-3t7e3-be32178718.json")))
		t = Time.now.to_i.to_s
		k.test_trigger_lis_poll(t)
		data = k.connection.get("organizations/#{ORGANIZATION_ID}")
		k.evented_poll_LIS_for_requisition(data)
		assert_equal 3, k.retry_count
	end
	###########################################
	##
	##
	##
	##
	##
	###########################################

	def test_deletes_order_in_response_to_event
		$redis = Redis.new
		$redis.del("orders")
		$redis.del("orders_sorted_set")
		$redis.del("last_request")
		$redis = Redis.new
		$redis.del("ruby_astm_log")
		k = Pf_Lab_Interface.new(nil,LIS_SECURITY_KEY,HOST,ORGANIZATION_ID,JSON.parse(IO.read("/home/bhargav/Downloads/ml-micro-analysis-firebase-adminsdk-3t7e3-be32178718.json")))
		t = Time.now.to_i.to_s
		
		k.test_trigger_lis_poll(t)

		data = k.connection.get("organizations/#{ORGANIZATION_ID}")
		#puts "TRIGGERED TEST TRIGGER LIS POLL AND GOT THE FOLLOWING DATA"
		#puts data
		k.evented_poll_LIS_for_requisition(data)
		
		all_orders = $redis.hgetall("orders")
		
		first_order_id = $redis.hkeys("orders")[0]
	
		assert_equal 20, all_orders.size

		k.test_trigger_delete_order(first_order_id)
		data = k.connection.get("organizations/#{ORGANIZATION_ID}")
		#puts "TRIGGERED DELETE AND GOT THE FOLLOWING DATA."
		#puts data.to_s
		k.evented_poll_LIS_for_requisition(data)

		all_orders = $redis.hgetall("orders")
		assert_equal 19, all_orders.size

	end

	# now the update result is a seperate daemon.
	# and item group and priority tests.

	#####################################
	##
	##
	## RETRY ORDER UPDATE TESTS
	##
	##
	#####################################

	def test_updates_results_for_order
		$redis = Redis.new
		$redis.del("orders")
		$redis.del("orders_sorted_set")
		$redis.del("last_request")
		$redis = Redis.new
		$redis.del("ruby_astm_log")

		k = Pf_Lab_Interface.new(nil,LIS_SECURITY_KEY,HOST,ORGANIZATION_ID,JSON.parse(IO.read("/home/bhargav/Downloads/ml-micro-analysis-firebase-adminsdk-3t7e3-be32178718.json")))
		t = Time.now.to_i.to_s

		k.test_trigger_lis_poll(t)

		data = k.connection.get("organizations/#{ORGANIZATION_ID}")
		#puts "TRIGGERED TEST TRIGGER LIS POLL AND GOT THE FOLLOWING DATA"
		#puts data
		k.evented_poll_LIS_for_requisition(data)
		
		all_orders = $redis.hgetall("orders")
		
		first_order_id = $redis.hkeys("orders")[0]

		assert_equal 20, all_orders.size

		## put to the patients.
		root_path = File.dirname __dir__
		pt_inr_patient_result_path = File.join root_path,'test','resources','pt_inr_result.json'

		result_hash = JSON.parse(IO.read(pt_inr_patient_result_path))
		puts result_hash.to_s
		result_hash["@patients"][0]["@orders"][0]["id"] = "abcdefg1"
		result_hash["@patients"][0]["@orders"][1]["id"] = "abcdefg1"
		$redis.lpush("patients",JSON.generate(result_hash["@patients"][0]))
		k.update_LIS(:exit_on_success => true)
	end

	## We try to sort it out.
	## item groups -> their creation -> downloading.
	## and changing priorities on test names.
	## i.e -> why not just add all the items.
	## when it polls for the requisition
	## we don't want to do certain tests on another machine.
	## whichever one has the first priority -> that's why i had made priorites.

	def test_update_failure_pushes_results_into_failed_list
		$redis = Redis.new
		$redis.del("orders")
		$redis.del("orders_sorted_set")
		$redis.del("last_request")
		$redis = Redis.new
		$redis.del("ruby_astm_log")
		$redis.del("failed_updates")

		k = Pf_Lab_Interface.new(nil,LIS_SECURITY_KEY,HOST,ORGANIZATION_ID,JSON.parse(IO.read("/home/bhargav/Downloads/ml-micro-analysis-firebase-adminsdk-3t7e3-be32178718.json")))
		t = Time.now.to_i.to_s

		k.test_trigger_lis_poll(t)

		data = k.connection.get("organizations/#{ORGANIZATION_ID}")
		#puts "TRIGGERED TEST TRIGGER LIS POLL AND GOT THE FOLLOWING DATA"
		k.evented_poll_LIS_for_requisition(data)
		
		all_orders = $redis.hgetall("orders")
		
		first_order_id = $redis.hkeys("orders")[0]
	
		assert_equal 20, all_orders.size

		## put to the patients.
		root_path = File.dirname __dir__
		pt_inr_patient_result_path = File.join root_path,'test','resources','pt_inr_result.json'

		result_hash = JSON.parse(IO.read(pt_inr_patient_result_path))
		puts result_hash.to_s
		result_hash["@patients"][0]["@orders"][0]["id"] = "abcdefg1"
		result_hash["@patients"][0]["@orders"][1]["id"] = "abcdefg1"
		$redis.lpush("patients",JSON.generate(result_hash["@patients"][0]))
		k.lis_security_key = "dog" 
		k.update_LIS(:exit_on_failure => true)
		assert_equal 1, $redis.scard("failed_updates")
	end

=end
	def test_polls_for_new_orders_on_startup
		$redis = Redis.new
		#$redis.del("orders")
		#$redis.del("orders_sorted_set")
		#$redis.del("last_request")
		$redis = Redis.new
		k = Pf_Lab_Interface.new(nil,LIS_SECURITY_KEY,HOST,ORGANIZATION_ID,JSON.parse(IO.read(PRIVATE_KEY_FILE)))
		k._start
	end


	## could sort this out, and now we move in for lis of all machines today itself.
	## it should be updating the orders
	## patient consent
	## we can add a certain storage requirement
	## 
	##############################################################
	##
	##
	## BARCODE PRIORITY CHANGE WITHIN A CATEGORY
	##
	##
	##############################################################
=begin
	def test_sequence
		## add one item
		## it goes to the lis
		## there it gets a result
		## now add another report, and another item
		## now it goes back to the lis
		## what happens when that gets reupdated.
	end


	def test_barcode_priority_change_triggers_poll

	end

	def test_barcode_change_responds_to_query_on_new_barcode

	end
=end
	## we have item groups -> barcodes -> 
	##########################################################
	##
	##
	##
	## INDIVIDUAL MACHINE RESULTS
	##
	##
	##
	##########################################################
=begin
	def test_updates_hemogram_results_to_lis
	end

	def test_updates_esr_to_lis
	end

	def test_updates_hba1c_to_lis
	end

	def test_updates_immunoassay_to_lis
	end

	def test_updates_biochem_to_lis
	end

	def test_updates_urine_to_lis
	end
=end

end	