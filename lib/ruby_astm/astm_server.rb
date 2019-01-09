require 'rubygems'
require 'eventmachine'
require 'em-rubyserial'
require "active_support/all"
require "json"
require "redis"

class AstmServer

	include LabInterface
	include UsbModule

	def self.log(message)
		puts "" + message
    	$redis.zadd("ruby_astm_log",Time.now.to_i,message)
  	end

  	def self.root_path
  		File.dirname __dir__
  	end

  	def self.default_mappings
  		File.join AstmServer.root_path,"mappings.json"
  	end

	$ENQ = "[5]"
	$start_text = "[2]"
	$end_text = "[3]"
	$record_end = "[13]"
	$frame_end = "[10]"

	def initialize(server_ip=nil,server_port=nil,mpg=nil,respond_to_queries=false)
		$redis = Redis.new
		AstmServer.log("Initializing AstmServer")
		self.server_ip = server_ip || "127.0.0.1"
		self.server_port = server_port || 3000
		self.respond_to_queries = respond_to_queries
		$mappings = JSON.parse(IO.read(mpg || AstmServer.default_mappings))
	end

	def start_server
		EventMachine.run {
			serial = EventMachine.open_serial('/dev/ttyS0', 9600, 8,LabInterface)
			puts "RUNNING SERIAL ON dev/ttyS0 ------------ #{serial.to_s}"
			self.ethernet_server = EventMachine::start_server self.server_ip, self.server_port, LabInterface
			AstmServer.log("Running ETHERNET SERVER on #{server_port}")
			usb = EventMachine.open_serial('/dev/ttyUSB0',19200,8)
			self.usb_response_bytes = []
			EM.add_periodic_timer(5) do
				puts "running usb on ttyUSB0"
				puts "sending machine data request #{request_results}"
			   usb.send_data(request_results)
			end
			usb.on_data do |data|
				parse_usb_response(data)
			end
		}
	end	

end
