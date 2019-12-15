require 'minitest/autorun'
require 'ruby_astm'

## to test this, you need a
class TestPfInterface < Minitest::Test
	
	HOST = "http://192.168.1.4:3000"
	LIS_SECURITY_KEY="y_u_RyjX5ApT8y_s9wsw"
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

	def test_auth_success
		k = Pf_Lab_Interface.new(nil,LIS_SECURITY_KEY)
		
		request = Typhoeus::Request.new(
			HOST + "/interfaces",
			method: :get,
			headers: { Accept: "application/json" },
			params: {lis_security_key: LIS_SECURITY_KEY}
		)

		request.run

		response = request.response

		assert_equal "200", response.code.to_s

	end
	
	#############################################
	##
	##
	## AUTH TESTS.
	##
	##
	#############################################
=begin
	def test_auth_success
		k = Pf_Lab_Interface.new(nil,"pathofast")
		
		request = Typhoeus::Request.new(
			HOST + "/interfaces",
			method: :get,
			headers: { Accept: "application/json" },
			params: {lis_security_key: "pathofast"}
		)

		request.run

		response = request.response

		assert_equal "200", response.code.to_s

	end


	def test_auth_failure

		k = Pf_Lab_Interface.new(nil,"pathofas")
		
		request = Typhoeus::Request.new(
			HOST + "/interfaces",
			method: :get,
			headers: { Accept: "application/json" },
			params: {lis_security_key: "no_key"}
		)

		request.run

		response = request.response

		assert_equal "401", response.code.to_s		

	end
=end
	## basically i have to finish this thing today.
	#############################################
	##
	##
	## POLL TESTS
	##
	##
	#############################################
	#def test_logs_poll_request_error

	#end	

=begin
	def test_adds_polled_orders_to_redis

		k = Pf_Lab_Interface.new(nil,"pathofast")
		
		k.poll

	end
=end
	#def test_adds_polled_order_barcoes_to_redis

	#end

	#def test_skips_results_till_size_is_reached

	#end

	##############################################
	##
	##
	## NOT FOUND TESTS.
	##
	##
	##############################################


	###################################################################
	##
	##
	## UPDATE TESTS
	##
	##
	###################################################################
=begin
	def test_updates_results_to_server
		data = [
			{
				:id => "1234",
				:results => [
					{
						:name => "UREA",
						:value => 10
					}
				]
			}
		]

		k = Pf_Lab_Interface.new(nil,"pathofast")

		k.update(data)
			
	end

	def returns_no_error_if_result_already_verified
		
	end
=end
	#def test_lis_code_clash_between_two_outsourced_organization_reports

	#end

	######################################################
	##
	##
	## REDIS DATA HAD TO BE CLEARED TESTS
	##
	##
	######################################################

	#def test_what_happens_if_redis_data_is_cleared_and_machine_sends_results

	#end


end	