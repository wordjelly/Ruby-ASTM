module LabInterface

	ACK = "\x06"
  mattr_accessor :headers

	def receive_data(data)
      puts "receiving data----------------------------------"
		  text = data.bytes.to_a.pack('c*')
      puts "processing text"
      puts text.to_s
		  process_text(text)
      puts "sending ACK"
      send_data(ACK)
  end

  def process_text(text)
		  line = Line.new({:text => text})
      process_type(line)
  end

  def process_type(line)
      case line.type
      when "Header"
        header = Header.new(line)
        self.headers ||= []
        self.headers << header
      when "Patient"
        patient = Patient.new(line)
        self.headers[-1].patients << patient
      when "Order"
        order = Order.new(line)
        self.headers[-1].patients[-1].orders << order
      when "Result"
        result = Result.new(line)
        self.headers[-1].patients[-1].orders[-1].results[result.name] = result
      when "Terminator"
        self.headers.each do |header|
          header.commit
        end
      end
  end

  def unbind
     puts "-- someone disconnected from the echo server!"
  end

end