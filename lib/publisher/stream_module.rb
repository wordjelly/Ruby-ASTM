module StreamModule

	SECRET = ENV["FIREBASE_SECRET"]
	SITE_URL = ENV["FIREBASE_SITE"]

	attr_accessor :on_message_handler_function
	attr_accessor :connection
	attr_accessor :private_key_hash
	attr_accessor :event_source
	## the event_stream object
	attr_accessor :es

	def setup_connection
		raise "please provide the private key hash, from firebase service account -> create private key " if self.private_key_hash.blank?
		raise "no event source endpoint provided" if self.event_source.blank?
		self.connection = RestFirebase.new :site => SITE_URL,
                     :secret => SECRET, :private_key_hash => private_key_hash, :auth_ttl => 1800
        self.on_message_handler_function ||= "on_message_handler"

	end

	def watch
		@reconnect = true
		self.es = self.connection.event_source(self.event_source)
		self.es.onopen   { |sock| p sock } # Called when connecte
		self.es.onmessage{ |event, data, sock| 
			#puts "event: #{event}"
			send(self.on_message_handler_function,data)
		}
		self.es.onerror  { |error, sock| p error } # Called 4
		self.es.onreconnect{ |error, sock| p error; @reconnect }
		self.es.start
		rd, wr = IO.pipe
		%w[INT TERM].each do |sig|
		  Signal.trap(sig) do
		    wr.puts # unblock the main thread
		  end
		end
		rd.gets # block main thread until INT or TERM received
		@reconnect = false
		self.es.close
		self.es.wait # shutdown cleanly
	end

	def watch_limited(seconds)
		
		@reconnect = true
		self.es = self.connection.event_source(self.event_source)
		self.es.onopen   { |sock| p sock } # Called when connecte
		self.es.onmessage{ |event, data, sock| 
			send(self.on_message_handler_function,data)
		}
		self.es.onerror  { |error, sock| p error } # Called 4
		self.es.onreconnect{ |error, sock| p error; @reconnect }
		self.es.start
		sleep(seconds)
		@reconnect = false
		self.es.close
		self.es.wait # shutdown cleanly
		
	end

	def on_message_handler(data)
		#puts "got some data"
		#puts data
	end

end