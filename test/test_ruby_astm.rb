#ruby_astm_test.rb
require 'minitest/autorun'
require 'ruby_astm'

class TestRubyAstm < Minitest::Test
	
  #def test_server
  #	server = AstmServer.new("192.168.1.14",3000,nil)
  #	server.start_server
  #end

=begin
  def test_sysmex_550_receives_results
  	server = AstmServer.new("127.0.0.1",3000,nil)
  	$redis.del("patients")
  	root_path = File.dirname __dir__
  	sysmex_input_file_path = File.join root_path,'test','resources','sysmex_550_sample.txt'
  	server.process_text_file(sysmex_input_file_path)
  	assert_equal 1, $redis.llen("patients")
  end

  def test_em_200_receives_results
  	server = AstmServer.new("127.0.0.1",3000,nil)
  	$redis.del("patients")
  	root_path = File.dirname __dir__
  	em200_input_file_path = File.join root_path,'test','resources','em_200_sample.txt'
  	server.process_text_file(em200_input_file_path)
  	assert_equal 2, $redis.llen("patients")
  end
=end

=begin
  def test_em_200_parses_query
  	server = AstmServer.new("127.0.0.1",3000,nil)
  	$redis.del("patients")
  	root_path = File.dirname __dir__
  	em200_input_file_path = File.join root_path,'test','resources','em_200_query_sample.txt'
  	server.process_text_file(em200_input_file_path)
  	assert_equal "010520182", server.headers[-1].queries[-1].sample_id
  end
=end

=begin
  def test_responds_to_query
    server = AstmServer.new("192.168.1.14",3000,nil,true)
    $redis.del("patients")
    server.start_server
    #server.send_enq
  end
=end

=begin
  def test_polls_server
    poller = Poller.new
    poller.poll_lis
  end
=end

=begin
  def test_pre_poll_LIS_no_existing_key
    poller = Poller.new
    $redis.flushall
    poller.pre_poll_LIS
    processing_status = JSON.parse($redis.get(Poller::POLL_STATUS_KEY))
    assert_equal Poller::RUNNING, processing_status[Poller::LAST_REQUEST_STATUS]
  end

  def test_pre_poll_LIS_running
    poller = Poller.new
    $redis.flushall
    poller.pre_poll_LIS
    processing_status = JSON.parse($redis.get(Poller::POLL_STATUS_KEY))
    assert_equal Poller::RUNNING, processing_status[Poller::LAST_REQUEST_STATUS]
    running_time = processing_status[Poller::LAST_REQUEST_AT]
    ## PRE POLL.
    poller.pre_poll_LIS
    processing_status = JSON.parse($redis.get(Poller::POLL_STATUS_KEY))
    assert_equal(running_time,processing_status[Poller::LAST_REQUEST_AT])
  end

  def test_pre_poll_LIS_expired_key
    poller = Poller.new
    $redis.flushall
    poller.pre_poll_LIS
    processing_status = JSON.parse($redis.get(Poller::POLL_STATUS_KEY))
    assert_equal Poller::RUNNING, processing_status[Poller::LAST_REQUEST_STATUS]
    expired_time = (Time.now - 10.years).to_i
    processing_status[Poller::LAST_REQUEST_AT] = (Time.now - 10.years).to_i
    $redis.set(Poller::POLL_STATUS_KEY,JSON.generate(processing_status))
    ## now pre poll again.
    ## the time should not be equal to processing time.
    poller.pre_poll_LIS
    processing_status = JSON.parse($redis.get(Poller::POLL_STATUS_KEY))
    assert_equal (processing_status[Poller::LAST_REQUEST_AT] == expired_time), false
  end

  def test_post_poll_LIS
    poller = Poller.new
    $redis.flushall
    poller.pre_poll_LIS
    processing_status = JSON.parse($redis.get(Poller::POLL_STATUS_KEY))
    assert_equal Poller::RUNNING, processing_status[Poller::LAST_REQUEST_STATUS]
    poller.post_poll_LIS
    processing_status = JSON.parse($redis.get(Poller::POLL_STATUS_KEY))
    assert_equal Poller::COMPLETED, processing_status[Poller::LAST_REQUEST_STATUS]
  end 
=end


  def test_poll_LIS_for_requisition
    poller = Poller.new
    poller.poll_LIS_for_requisition
  end

  ## now comes the actual loading and dumping.
  ## and the mapping of the keys.

end