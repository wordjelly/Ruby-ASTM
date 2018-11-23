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

	def initialize(server_ip,server_port,mpg,respond_to_queries=false)
		self.server_ip = server_ip || "192.168.1.14"
		self.server_port = server_port || 3000
		self.respond_to_queries = respond_to_queries
		$mappings = JSON.parse(IO.read(mpg || ("mappings.json")))
		$redis = Redis.new
	end

	def start_server
		EventMachine.run {
			self.server_signature = EventMachine::start_server self.server_ip, self.server_port, LabInterface
			puts "running ASTM SERVER on #{server_port}"
		}
	end	


=begin
	IO.read("sample.txt").each_line do |l|
		process_text(l)
	end
=end


end