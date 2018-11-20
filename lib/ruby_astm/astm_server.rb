require 'rubygems'
require 'eventmachine'
require "active_support/all"
require "json"
require "redis"

class AstmServer

	include LabInterface

	$ENQ = "[5]"
	$start_text = "[2]"
	$end_text = "[3]"
	$record_end = "[13]"
	$frame_end = "[10]"

	def initialize(server_ip,server_port,mpg)
		server_ip ||= "192.168.1.14"
		server_port ||= 3000
		mpg = JSON.parse(IO.read("mappings.json"))
		$mappings = mpg
		$redis = Redis.new
		EventMachine.run {
		  EventMachine::start_server server_ip, server_port, LabInterface
		  puts "running ASTM SERVER on #{server_port}"
		}
	end

=begin
	IO.read("sample.txt").each_line do |l|
		process_text(l)
	end
=end


end