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

  def test_em_200_parses_query
  	server = AstmServer.new("127.0.0.1",3000,nil)
  	$redis.del("patients")
  	root_path = File.dirname __dir__
  	em200_input_file_path = File.join root_path,'test','resources','em_200_query_sample.txt'
  	server.process_text_file(em200_input_file_path)
  	assert_equal "010520182", server.headers[-1].queries[-1].sample_id
  end


  def test_responds_to_query

  end

=begin
  
  def test_logs_results

  end
  
  def test_logs_any_errors

  end
  
  def test_polls
  
  end
=end

end