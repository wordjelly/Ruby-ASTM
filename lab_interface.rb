module LabInterface

	ACK = "\x06"
  mattr_accessor :machines

	def receive_data(data)
		  text = data.bytes.to_a.pack('c*')
		  process_text(text)
      send_data(ACK)
   	end

   	def process_text(text)
   		#puts "text is: #{text}"
		  line = Line.new({:text => text})
      process_type(line)
   	end

    def process_type(line)
      case line.type
      when "Header"
        header = Header.new(line)
        self.machines ||= []
        self.machines << header
      when "Patient"
        patient = Patient.new(line)
        self.machines[-1].patients << patient
      when "Order"
        order = Order.new(line)
        self.machines[-1].patients[-1].orders << order
      when "Result"
        result = Result.new(line)
        self.machines[-1].patientw[-1].orders[-1].results << result
      when "Terminator"
        self.machines.each do |header|
          header.commit
        end
      end
    end

   	def unbind
     puts "-- someone disconnected from the echo server!"
   	end

end