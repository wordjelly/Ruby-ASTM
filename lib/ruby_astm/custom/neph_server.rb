class NephServer

	include NephModule

	## DEFAULT SERIAL PORT : /dev/ttyS0
	## DEFAULT USB PORT : /dev/ttyUSB0
	## @param[Array] ethernet_connections : each element is expected to be a hash, with keys for :server_ip, :server_port.
	## @param[Array] serial_connections : each element is expected to be a hash with port_address, baud_rate, and parity
	#def initialize(server_ip=nil,server_port=nil,mpg=nil,respond_to_queries=false,serial_port='/dev/ttyS0',usb_port='/dev/ttyUSB0',serial_baud=9600,serial_parity=8,usb_baud=19200,usb_parity=8)
	def initialize(ethernet_connections,serial_connections,mpg=nil,respond_to_queries=nil,options=nil)
		$redis = Redis.new
		self.class.log("Initializing AstmServer")
		self.ethernet_connections = ethernet_connections
		self.serial_connections = serial_connections
		self.server_ip = server_ip || "127.0.0.1"
		self.server_port = server_port || 3000
		self.respond_to_queries = respond_to_queries
		self.serial_port = serial_port
		self.serial_baud = serial_baud
		self.serial_parity = serial_parity
		self.usb_port = usb_port
		self.usb_baud = usb_baud
		self.usb_parity = usb_parity
		self.parse_options(options) unless options.blank?
		$mappings = JSON.parse(IO.read(mpg || self.class.default_mappings))
	end


	def start_server
		EventMachine.run {
			self.ethernet_connections.each do |econn|
				raise "please provide a valid ethernet configuration with ip address" unless econn[:server_ip]
				raise "please provide a valid ethernet configuration with port" unless econn[:server_port]
				EventMachine::start_server econn[:server_ip], econn[:server_port],NephModule
				self.class.log("Running ETHERNET  with configuration #{econn}")
			end
			self.serial_connections.each do |sconn|
				raise "please provide a valid serial configuration with port address" unless sconn[:port_address]
				raise "please provide a valid serial configuration with baud rate" unless sconn[:baud_rate]
				raise "please provide a valid serial configuration with parity" unless sconn[:parity]
				EventMachine.open_serial(sconn[:port_address], sconn[:baud_rate], sconn[:parity],NephModule)
				puts "RUNNING SERIAL port with configuration : #{sconn}"
			end

		}
	end	

end