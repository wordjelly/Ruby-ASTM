require 'rubygems'
require 'eventmachine'
require 'em-rubyserial'
require "active_support/all"
require "json"
require "redis"

class AstmServer

	include LabInterface

	def self.log(message)
		puts "" + message
    	$redis.zadd("ruby_astm_log",Time.now.to_i,message)
  	end

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
			serial = EventMachine.open_serial('/dev/ttyUSB0', 9600, 8)
			serial.on_data do |data|
			  	puts "got some data"
			  	puts data.to_s
			    serial.send_data("\X06")
			end
			puts "running ASTM SERVER on #{server_port}"
		}
	end	

end