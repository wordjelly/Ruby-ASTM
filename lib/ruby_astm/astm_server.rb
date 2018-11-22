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
		self.server_ip = server_ip || "192.168.1.14"
		self.server_port = server_port || 3000
		$mappings = JSON.parse(IO.read("mappings.json"))
		$redis = Redis.new
	end

	def start_server
		EventMachine.run {
			puts "Server ip and port is:"
			puts self.server_ip
			puts self.server_port
			self.server_signature = EventMachine::start_server self.server_ip, self.server_port, LabInterface
			#puts "signature is:#{self.server_signature}"
			puts "running ASTM SERVER on #{server_port}"
		}
	end	


=begin
	IO.read("sample.txt").each_line do |l|
		process_text(l)
	end
=end


end