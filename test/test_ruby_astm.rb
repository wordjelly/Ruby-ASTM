#ruby_astm_test.rb
require 'minitest/autorun'
require 'ruby_astm'

class TestRubyAstm < Minitest::Test

  def setup
    $redis = Redis.new
    $redis.flushall
  end

  def test_esr_repeats
    $redis.del("patients")
    e = Esr.new
    root_path = File.dirname __dir__
    input_file_path = File.join root_path,'test','resources','esr_server_data.txt'
    byte_arr = eval(IO.read(input_file_path))
    e.parse_bytes(byte_arr)
    puts $redis.lrange("patients",0,-1)
  end

=begin
  def test_d10_bug
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
    #$redis.del("patients")
    root_path = File.dirname __dir__
    input_file_path = File.join root_path,'test','resources','d10_error.txt'
    server.process_byte_file(input_file_path)
  end


  def test_stago
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
    #$redis.del("patients")
    root_path = File.dirname __dir__
    input_file_path = File.join root_path,'test','resources','stago.txt'
    server.process_byte_file(input_file_path)
    #assert_equal 1, $redis.llen("patients")
    #patient = JSON.parse($redis.lrange("patients",0,0)[0])
    #assert_equal "pragya", patient["@orders"][0]["id"]
    #assert_equal "0.325", patient["@orders"][0]["results"]["HIV"]["value"]
    #assert_equal "0.318", patient["@orders"][0]["results"]["HBS"]["value"]
  end

  def test_ignores_same_electrolyte_result
    $redis = Redis.new
    $redis.del("patients")
    $redis.del(SiemensAbgElectrolyteModule::SIEMENS_ELEC_ABG_RESULTS_HASH)
    server = SiemensAbgElectrolyteServer.new([],[])
    root_path = File.dirname __dir__
    electrolyte_input_file_path = File.join root_path,'electrolytes_plain_text.txt'
    server.process_text_file(electrolyte_input_file_path)
    assert_equal 2, $redis.llen("patients")
    server = SiemensAbgElectrolyteServer.new([],[])
    root_path = File.dirname __dir__
    electrolyte_input_file_path = File.join root_path,'electrolytes_plain_text.txt'
    server.process_text_file(electrolyte_input_file_path)
    assert_equal 2, $redis.llen("patients")
  end

  def test_siemens_electrolyte
    $redis = Redis.new
    server = SiemensAbgElectrolyteServer.new([],[])
    root_path = File.dirname __dir__
    electrolyte_input_file_path = File.join root_path,'electrolytes_plain_text.txt'
    server.process_text_file(electrolyte_input_file_path)
    puts JSON.pretty_generate(JSON.parse(server.headers[-1].to_json))
    assert_equal server.headers[-1].patients.size, 2
    assert_equal server.headers[-1].patients[0].orders[0].results["po2"].value, "145.4"
    assert_equal server.headers[-1].patients[0].orders[0].results["pco2"].value, "8.9"
    assert_equal server.headers[-1].patients[0].orders[0].results["pH"].value, "7.973"
    assert_equal server.headers[-1].patients[0].orders[0].results["SNATRIUM"].value, "134"
    assert_equal server.headers[-1].patients[0].orders[0].results["SPOTASSIUM"].value, "3.38"
    assert_equal server.headers[-1].patients[0].orders[0].results["SCHLORIDE"].value, "94"
  end


  def test_print_errors
    $redis = Redis.new
    errors = $redis.zrange("ruby_astm_log",0 ,-1)
    errors.each do |error|
      puts error.to_s
      puts "-----------------------------------"
    end
  end


  def test_assigns_tubes_for_pre_op_package
    p = Poller.new

    record = []
    
    29.times do |i|
      if i == 7
        record[i] = "pre_op_package"
      elsif i == 24
        record[i] = "edta1234"
      elsif i == 25
        record[i] = "serum1234"
      elsif i == 26
        record[i] = "plasma1234"
      elsif i == 27
        record[i] = "fluoride1234"
      elsif i == 28
        record[i] = "urine1234"
      elsif i == 29
        record[i] = "esr1234"
      else
        record[i] = ""
      end
    end

    tests_hash = p.build_tests_hash(record)

    assert_equal tests_hash.deep_symbolize_keys, {:"EDTA:edta1234"=>["WBC", "RBC", "HGB", "HCT", "MCV", "MCH", "MCHC", "PLT", "NEUT%", "LYMPH%", "MONO%", "EO%", "BASO%", "NEUT#", "LYMPH#", "MONO#", "EO#", "BASO#", "RDW-CV"], :"SERUM:serum1234"=>[], :"PLASMA:plasma1234"=>["5", "4"], :"FLUORIDE:fluoride1234"=>["GLUR"], :"URINE_CONTAINER:urine1234"=>["GLU", "BIL", "KET", "SG", "BLO", "pH", "PRO", "URO", "NIT", "LEU", "COL", "CLA","CRE","UALB"]}.deep_symbolize_keys
  end

  def test_assigns_tubes_for_lipid_profile

    p = Poller.new

    record = []
    
    29.times do |i|
      if i == 7
        record[i] = "lipid_profile"
      elsif i == 24
        record[i] = "edta1234"
      elsif i == 25
        record[i] = "serum1234"
      elsif i == 26
        record[i] = "plasma1234"
      elsif i == 27
        record[i] = "fluoride1234"
      elsif i == 28
        record[i] = "urine1234"
      elsif i == 29
        record[i] = "esr1234"
      else
        record[i] = ""
      end
    end

    tests_hash = p.build_tests_hash(record)

    assert_equal tests_hash.deep_symbolize_keys, {"EDTA:edta1234":[],"SERUM:serum1234":["CHOL","TRIGO","HDLC","LDL","VLDL"],"PLASMA:plasma1234":[],"FLUORIDE:fluoride1234":[],"URINE_CONTAINER:urine1234":[]}.deep_symbolize_keys

  end


  def test_assigns_tubes_for_liver_function_tests

    p = Poller.new

    record = []
    
    29.times do |i|
      if i == 7
        record[i] = "liver_function_tests"
      elsif i == 24
        record[i] = "edta1234"
      elsif i == 25
        record[i] = "serum1234"
      elsif i == 26
        record[i] = "plasma1234"
      elsif i == 27
        record[i] = "fluoride1234"
      elsif i == 28
        record[i] = "urine1234"
      elsif i == 29
        record[i] = "esr1234"
      else
        record[i] = ""
      end
    end

    tests_hash = p.build_tests_hash(record)
   

    assert_equal tests_hash.deep_symbolize_keys,
{"EDTA:edta1234":[],"SERUM:serum1234":["ALB","GGTP","BIDDY","CAA","BITDY","INBDY","ALPE","GOT","GPT"],"PLASMA:plasma1234":[],"FLUORIDE:fluoride1234":[],"URINE_CONTAINER:urine1234":[]}.deep_symbolize_keys

  end


  def test_assigns_tubes_for_kidney_function_tests
    p = Poller.new

    record = []
    
    29.times do |i|
      if i == 7
        record[i] = "kidney_function_tests"
      elsif i == 24
        record[i] = "edta1234"
      elsif i == 25
        record[i] = "serum1234"
      elsif i == 26
        record[i] = "plasma1234"
      elsif i == 27
        record[i] = "fluoride1234"
      elsif i == 28
        record[i] = "urine1234"
      elsif i == 29
        record[i] = "esr1234"
      else
        record[i] = ""
      end
    end

    tests_hash = p.build_tests_hash(record)

    puts tests_hash.to_s

    assert_equal tests_hash.deep_symbolize_keys, {"EDTA:edta1234"=>[], "SERUM:serum1234"=>["CREAT", "UREA", "BUNC"], "PLASMA:plasma1234"=>[], "FLUORIDE:fluoride1234"=>[], "URINE_CONTAINER:urine1234"=>[]}.deep_symbolize_keys

  end

  def test_assigns_tubes_for_full_body_package

    p = Poller.new

    record = []
    
    29.times do |i|
      if i == 7
        record[i] = "full_body_package"
      elsif i == 24
        record[i] = "edta1234"
      elsif i == 25
        record[i] = "serum1234"
      elsif i == 26
        record[i] = "plasma1234"
      elsif i == 27
        record[i] = "fluoride1234"
      elsif i == 28
        record[i] = "urine1234"
      elsif i == 29
        record[i] = "esr1234"
      else
        record[i] = ""
      end
    end

    tests_hash = p.build_tests_hash(record)

   
    assert_equal tests_hash.deep_symbolize_keys,{:"EDTA:edta1234"=>["A1c", "WBC", "RBC", "HGB", "HCT", "MCV", "MCH", "MCHC", "PLT", "NEUT%", "LYMPH%", "MONO%", "EO%", "BASO%", "NEUT#", "LYMPH#", "MONO#", "EO#", "BASO#", "RDW-CV"], :"SERUM:serum1234"=>["CHOL", "TRIGO", "HDLC", "LDL", "VLDL", "CREAT", "UREA", "BUNC", "ALB", "GGTP", "BIDDY", "CAA", "BITDY", "INBDY", "ALPE", "GOT", "GPT", "HOMCY", "SIRON", "SUIBC", "STIBC", "UA", "PHOS", "MG", "SNATRIUM", "SPOTASSIUM", "SCHLORIDE", "11", "10", "9", "8", "7", "6", "3", "1"], :"PLASMA:plasma1234"=>["2"], :"FLUORIDE:fluoride1234"=>["GLUR", "GLUPP", "GLUF"], :"URINE_CONTAINER:urine1234"=>["GLU", "BIL", "KET", "SG", "BLO", "pH", "PRO", "URO", "NIT", "LEU", "COL", "CLA","CRE","UALB"]}.deep_symbolize_keys

  end


  def test_query_for_non_existent_sample
    $redis = Redis.new
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
    root_path = File.dirname __dir__
    roche_input_file_path = File.join root_path,'test','resources','roche_query_for_non_existent_sample.txt'
    server.process_text_file(roche_input_file_path)
    header_responses = server.headers[-1].build_one_response({machine_name: "cobas-e411"})
    assert_equal header_responses[0], "1H|\\^&|||host^1|||||cobas-e411|TSDWN^REPLY|P|1\r"
  end


  def test_roche_multi_frame_bytes
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])

    $redis.del("patients")
    root_path = File.dirname __dir__
    roche_input_file_path = File.join root_path,'test','resources','roche_multi_frame_bytes.txt'
    byte_arr = eval(IO.read(roche_input_file_path))
    db = ''
    byte_arr.map{|c| db += server.pre_process_bytes(c,'')
    }
    server.process_text(db)
    assert_equal 1, $redis.llen("patients")
    patient = JSON.parse($redis.lrange("patients",0,0)[0])
    #assert_equal "pragya", patient["@orders"][0]["id"]
    assert_equal "141.3", patient["@orders"][0]["results"]["B12"]["value"]
    assert_equal "<3.00", patient["@orders"][0]["results"]["VITD"]["value"]
    assert_equal "1.95", patient["@orders"][0]["results"]["TSH"]["value"]
    assert_equal "132.1", patient["@orders"][0]["results"]["T3"]["value"]
    assert_equal "9.61", patient["@orders"][0]["results"]["T4"]["value"]
    assert_equal "0.282", patient["@orders"][0]["results"]["HIV"]["value"]
    assert_equal "0.707", patient["@orders"][0]["results"]["HBS"]["value"]
  end



  def test_roche_response_is_generated
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
    $redis.del("patients")
    root_path = File.dirname __dir__
    roche_input_file_path = File.join root_path,'test','resources','roche_enquiry.txt'
    server.process_text_file(roche_input_file_path)
    $redis.hset("requisitions_hash","0000000387",JSON.generate(["1","2"]))
    header_responses = server.headers[-1].build_one_response({machine_name: "cobas-e411"})
    puts header_responses.to_s
  end


  def test_roche_result
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
    $redis.del("patients")
    root_path = File.dirname __dir__
    roche_input_file_path = File.join root_path,'test','resources','roche_result.txt'
    server.process_text_file(roche_input_file_path)
    assert_equal 1, $redis.llen("patients")
    patient = JSON.parse($redis.lrange("patients",0,0)[0])
    assert_equal "pragya", patient["@orders"][0]["id"]
    assert_equal "0.325", patient["@orders"][0]["results"]["HIV"]["value"]
    assert_equal "0.318", patient["@orders"][0]["results"]["HBS"]["value"]
  end


  def test_roche_inquiry_is_parsed
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
    $redis.del("patients")
    root_path = File.dirname __dir__
    roche_input_file_path = File.join root_path,'test','resources','roche_enquiry.txt'
    server.process_text_file(roche_input_file_path)
    assert_equal "0000000387", server.headers[-1].queries[-1].sample_ids[0]
  end
  
  


  def test_receives_siemens_results
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
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
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
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
  	ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
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
  	ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
  	$redis.del("patients")
  	root_path = File.dirname __dir__
  	em200_input_file_path = File.join root_path,'test','resources','em_200_sample.txt'
  	server.process_text_file(em200_input_file_path)
  	assert_equal 2, $redis.llen("patients")
    patient = JSON.parse($redis.lrange("patients",0,0)[0])
    assert_equal "Asha Singh1", patient["@orders"][0]["id"]
  end

  def test_em_200_parses_query
  	ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
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
    ## here the only issue is that it is dependent, so we cannot test this like this. \
    first_inst = Time.now.to_i*1000
    second_inst = first_inst + 1
    lis_response = {
      first_inst.to_s => [
        [nil, nil, nil, nil, nil, nil, nil, "HIV,HBS,ESR,GLUPP", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "Lavender:barcode", "Serum:barcode", "Plasma:barcode", "Fluoride:barcode", "Urine:barcode", "ESR:barcode"]
      ],
      second_inst.to_s => [
        [nil, nil, nil, nil, nil, nil, nil, "HIV,HBS,ESR,GLUPP", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "Lavender:barcode", "Serum:barcode", "Plasma:barcode", "Fluoride:barcode", "Urine:barcode", "ESR:barcode"]
      ]
    }
    poller.process_LIS_response(JSON.generate(lis_response))
    checkpoint = poller.get_checkpoint
    assert_equal second_inst.to_s,checkpoint.to_s
  end

  def test_query_uses_requisitions_hash_to_generate_response
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
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
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
    assert_equal "D4", server.checksum(IO.read(e411_checksum_file_path))
  end


  def test_script_error_in_update_reverts_redis_rpoplpush
    Poller.class_eval do 
      def update(data)
        false
      end
    end    
    ethernet_connections = [{:server_ip => "127.0.0.1", :server_port => 3000}]
    server = AstmServer.new(ethernet_connections,[])
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
=end

end