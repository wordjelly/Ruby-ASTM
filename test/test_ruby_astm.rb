#ruby_astm_test.rb
require 'minitest/autorun'
require 'ruby_astm'

class TestRubyAstm < Minitest::Test

=begin
  def test_server
    server = AstmServer.new("192.168.1.7",3000,nil)
    server.start_server
  end
=end

=begin
  def test_serial_server
    $redis = Redis.new
    $mappings = JSON.parse(IO.read(AstmServer.default_mappings))
    EM.run do
      serial = EventMachine.open_serial('/dev/ttyS0', 9600, 8,LabInterface)
      puts "serial is:"
      puts serial.to_s
      #serial.on_data do |data|
      #  puts data.bytes.to_a.pack('c*')
      #  puts "sending ACK"
      #  serial.send_data([6].pack('c*'))
      #end
    end
  end
=end


  def test_roche_result
    server = AstmServer.new("127.0.0.1",3000,nil)
    $redis.del("patients")
    root_path = File.dirname __dir__
    roche_input_file_path = File.join root_path,'test','resources','roche_result.txt'
    server.process_text_file(roche_input_file_path)
    #server.headers[-1].commit
    assert_equal 1, $redis.llen("patients")
    patient = JSON.parse($redis.lrange("patients",0,0)[0])
    assert_equal "pragya", patient["@orders"][0]["id"]
  end


  def test_receives_siemens_results
    server = AstmServer.new("127.0.0.1",3000,nil)
    $redis.del("patients")
    root_path = File.dirname __dir__
    siemens_input_file_path = File.join root_path,'test','resources','siemens_clinitek.txt'
    server.process_text_file(siemens_input_file_path)
    server.headers[-1].commit
    assert_equal 1, $redis.llen("patients")
    patient = JSON.parse($redis.lrange("patients",0,0)[0])
    assert_equal "Clear", patient["@orders"][0]["results"]["CLA"]["value"]
    assert_equal "Yellow", patient["@orders"][0]["results"]["COL"]["value"]
    assert_equal "6.0", patient["@orders"][0]["results"]["pH"]["value"]
    assert_equal "010820187", patient["@orders"][0]["id"]
  end


  def test_generates_ack_message_for_hl7_protocol
    server = AstmServer.new("127.0.0.1",3000,nil)
    $redis.del("patients")
    root_path = File.dirname __dir__
    siemens_input_file_path = File.join root_path,'test','resources','siemens_clinitek.txt'
    server.process_text_file(siemens_input_file_path)
    server.headers[-1].commit
    ack_success = server.headers[-1].generate_ack_success_response
    puts ack_success.to_s
    ## so instead of this data, it has to send back the rest of it.
  end
  

  def test_sysmex_550_receives_results
  	server = AstmServer.new("127.0.0.1",3000,nil)
  	$redis.del("patients")
  	root_path = File.dirname __dir__
  	sysmex_input_file_path = File.join root_path,'test','resources','sysmex_550_sample.txt'
  	server.process_text_file(sysmex_input_file_path)
    patient = JSON.parse($redis.lrange("patients",0,0)[0])
    assert_equal "16.4", patient["@orders"][0]["results"]["HBparam"]["value"]
  	assert_equal "16740", patient["@orders"][0]["results"]["TLCparam"]["value"]
    assert_equal "586000", patient["@orders"][0]["results"]["PCparam"]["value"]
    assert_equal 1, $redis.llen("patients")
  end

  def test_em_200_receives_results
  	server = AstmServer.new("127.0.0.1",3000,nil)
  	$redis.del("patients")
  	root_path = File.dirname __dir__
  	em200_input_file_path = File.join root_path,'test','resources','em_200_sample.txt'
  	server.process_text_file(em200_input_file_path)
  	assert_equal 2, $redis.llen("patients")
    patient = JSON.parse($redis.lrange("patients",0,0)[0])
    assert_equal "Asha Singh1", patient["@orders"][0]["id"]
  end

  def test_em_200_parses_query
  	server = AstmServer.new("127.0.0.1",3000,nil)
  	$redis.del("patients")
  	root_path = File.dirname __dir__
  	em200_input_file_path = File.join root_path,'test','resources','em_200_query_sample.txt'
  	server.process_text_file(em200_input_file_path)
  	assert_equal "010520182", server.headers[-1].queries[-1].sample_ids[0]
  end

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

  def test_process_LIS_response
    poller = Poller.new
    $redis.del Poller::REQUISITIONS_SORTED_SET
    $redis.del Poller::REQUISITIONS_HASH
    ## here the only issue is that it is dependent, so we cannot test this like this. 
    lis_response = {
      "1543490233000" => [
        [nil, nil, nil, nil, nil, nil, nil, "HIV,HBS,ESR,GLUPP", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "Lavender:barcode", "Serum:barcode", "Plasma:barcode", "Fluoride:barcode", "Urine:barcode", "ESR:barcode"]
      ]
    }
    poller.process_LIS_response(JSON.generate(lis_response))
    ## now assert redis.
    sorted_set = $redis.zrange Poller::REQUISITIONS_SORTED_SET, 0, -1, {withscores: true}
    assert_equal 1, sorted_set.size
    assert_equal 1543490233000.0, sorted_set[0][1]
    assert_equal [["{\"EDTA:Lavender:barcode\":[],\"SERUM:Serum:barcode\":[],\"PLASMA:Plasma:barcode\":[\"5\",\"4\"],\"FLUORIDE:Fluoride:barcode\":[\"GLUPP\"],\"URINE_CONTAINER:Urine:barcode\":[],\"ESR:ESR:barcode\":[\"ESR\"]}", 1543490233000.0]], sorted_set
    requisitions_hash = $redis.hgetall Poller::REQUISITIONS_HASH
    assert_equal requisitions_hash, {"Lavender:barcode"=>"[]", "Serum:barcode"=>"[]", "Plasma:barcode"=>"[\"5\",\"4\"]", "Fluoride:barcode"=>"[\"GLUPP\"]", "Urine:barcode"=>"[]", "ESR:barcode"=>"[\"ESR\"]"}
    
  end


  ## these two specs have to pass.
  def test_polls_for_requisitions_after_checkpoint
    poller = Poller.new
    $redis.del Poller::REQUISITIONS_SORTED_SET
    $redis.del Poller::REQUISITIONS_HASH
    ## here the only issue is that it is dependent, so we cannot test this like this. 
    lis_response = {
      "1543490233000" => [
        [nil, nil, nil, nil, nil, nil, nil, "HIV,HBS,ESR,GLUPP", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "Lavender:barcode", "Serum:barcode", "Plasma:barcode", "Fluoride:barcode", "Urine:barcode", "ESR:barcode"]
      ],
      "1543490233001" => [
        [nil, nil, nil, nil, nil, nil, nil, "HIV,HBS,ESR,GLUPP", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "Lavender:barcode", "Serum:barcode", "Plasma:barcode", "Fluoride:barcode", "Urine:barcode", "ESR:barcode"]
      ]
    }
    poller.process_LIS_response(JSON.generate(lis_response))
    checkpoint = poller.get_checkpoint
    assert_equal checkpoint, 1543490233001
  end

  def test_query_uses_requisitions_hash_to_generate_response
    server = AstmServer.new("127.0.0.1",3000,nil)
    $redis.del("patients")
    root_path = File.dirname __dir__
    em200_input_file_path = File.join root_path,'test','resources','em_200_query_sample.txt'
    ## add an entry for the id specified in the query.
    $redis.hset(Poller::REQUISITIONS_HASH,"010520182",JSON.generate(["GLUR"]))
    server.process_text_file(em200_input_file_path)
    tests = server.headers[-1].queries[-1].get_tests("010520182")
    assert_equal tests, JSON.parse($redis.hget(Poller::REQUISITIONS_HASH,"010520182"))
  end


  def test_calculates_checksum_correctly
    root_path = File.dirname __dir__
    e411_checksum_file_path = File.join root_path,'test','resources','e411_checksum.txt'
    server = AstmServer.new("127.0.0.1",3000,nil)
    assert_equal "D4", server.checksum(IO.read(e411_checksum_file_path))
  end


  def test_script_error_in_update_reverts_redis_rpoplpush
    Poller.class_eval do 
      def update(data)
        false
      end
    end    
    server = AstmServer.new("127.0.0.1",3000,nil)
    $redis.del("patients")
    root_path = File.dirname __dir__
    sysmex_input_file_path = File.join root_path,'test','resources','sysmex_550_sample.txt'
    server.process_text_file(sysmex_input_file_path)
    p = Poller.new
    p.update_LIS
    ## resetting.
    Poller.class_eval do 
      def update(data)
        true
      end
    end    
    ## it should be that this is still there in the patients.
    assert_equal 1, $redis.llen("patients")

  end 


=begin
  ## kindly note, the credentials specified herein are no longer active ;)
  def test_initialized_google_lab_interface
    goog = Google_Lab_Interface.new(nil,"/home/bhargav/Desktop/credentials.json","/home/bhargav/Desktop/token.yaml","MNWKZC-L05-ufApJTSqaLq42yotVzKYhk")    
  end 
=end

end