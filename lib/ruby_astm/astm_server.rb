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


	## DEFAULT SERIAL PORT : /dev/ttyS0
	## DEFAULT USB PORT : /dev/ttyUSB0
	def initialize(server_ip=nil,server_port=nil,mpg=nil,respond_to_queries=false,serial_port='/dev/ttyS0',usb_port='/dev/ttyUSB0',serial_baud=9600,serial_parity=8,usb_baud=19200,usb_parity=8)
		$redis = Redis.new
		AstmServer.log("Initializing AstmServer")
		self.server_ip = server_ip || "127.0.0.1"
		self.server_port = server_port || 3000
		self.respond_to_queries = respond_to_queries
		self.serial_port = serial_port
		self.serial_baud = serial_baud
		self.serial_parity = serial_parity
		self.usb_port = usb_port
		self.usb_baud = usb_baud
		self.usb_parity = usb_parity
		$mappings = JSON.parse(IO.read(mpg || AstmServer.default_mappings))
	end

	def start_server
		EventMachine.run {
			serial = EventMachine.open_serial(serial_port, serial_baud, serial_parity,LabInterface)
			puts "RUNNING SERIAL ON #{serial_port} ------------ #{serial.to_s}"
			self.ethernet_server = EventMachine::start_server self.server_ip, self.server_port, LabInterface
			AstmServer.log("Running ETHERNET SERVER on #{server_port}")

		}
	end	

end

#sudham61@gmail.com