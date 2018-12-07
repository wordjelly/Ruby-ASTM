require "active_support/all"

module LabInterface

	ACK = "\x06"
  ENQ = "\x05"
  STX = "\x02"
  LF = "\x10"
  CR = "\x13"
  ETX = "\x03"
  EOT = "\x04"



  mattr_accessor :headers
  mattr_accessor :ethernet_server
  mattr_accessor :server_ip
  mattr_accessor :server_port
  mattr_accessor :mapping
  mattr_accessor :respond_to_queries

  ## buffer of incoming data.
  mattr_accessor :data_buffer
    

  ## returns the root directory of the gem.
  def root
      File.dirname __dir__
  end

  ## can process a file which contains ASTM output.
  ## this method is added so that you can load previously generated ASTM output into your database
  ## it also simplifies testing.
  def process_text_file(full_file_path)
    #full_file_path ||= File.join root,'../test','resources','sysmex_550_sample.txt'
    IO.read(full_file_path).each_line do |line|
      line.split('\\r').each do |txt| 
        process_text(txt)
      end
    end
  end


  def terminator
    "L|1|N\r"
  end


  def checksum(input)
    strString = input
    checksum = strString.sum
    b = checksum.to_s(16)
    strCksm = b[-2..-1]
    if strCksm.length < 2 
      for i in strString.length..1
         strCksm = "0" + strCksm
      end
    end
    strCksm.upcase
  end

	def receive_data(data)
      
      self.data_buffer ||= ''

      puts "incoming data bytes."

      concat = ""
      
      puts data.bytes.to_a.to_s

      data.bytes.to_a.each do |byte|
        x = [byte].pack('c*').force_encoding('UTF-8')
        if x == "\r"
          concat+="\n"
        elsif x == "\n"
          #puts "new line found --- "
          concat+=x
          #puts "last thing in concat."
          #puts concat[-1].to_s
        else
          concat+=x
        end
      end
      
      #puts "concat is:"
      
      #puts concat.to_s
      
      self.data_buffer << concat

      ## if the last byte is EOT, then call process text.
      ## inside that split by line and process one at a time.
      ##process_text(concat)      
      

      if data.bytes.to_a[-1] == 4
        #puts self.data_buffer
        process_text(self.data_buffer)
        self.data_buffer = ''
        send_data(ENQ)
      elsif data.bytes.to_a[0] == 6
        header_responses = self.headers[-1].build_one_response
        header_responses.each_with_index {|response,key|
          #puts "response is:"
          #response.bytes.to_a.each do |b|
          #  puts [b].pack('c*')
          #end
          message_checksum = checksum(response + terminator + ETX)
          #puts "Calculated checksum is: #{message_checksum}"
          final_resp = STX + response + terminator + ETX + message_checksum + "\r" 
          final_resp_arr = final_resp.bytes.to_a
          final_resp_arr << 10
          #puts final_resp_arr.to_s
          if (self.headers[-1].response_sent == false)
            puts "sending the  data as follows----------------------------------------------"
            puts "response sent is:"
            puts self.headers[-1].response_sent
            puts final_resp_arr.pack('c*').gsub(/\r/,'\n')
            send_data(final_resp_arr.pack('c*')) 
            self.headers[-1].response_sent = true if (key == (header_responses.size - 1))
          else
            send_data(EOT)
          end
        }
      else
        ## send the header 
        #puts "--------- SENT ACK -----------"
        if self.headers.blank?
          send_data(ACK)
        else
          if self.headers[-1].is_astm?
            send_data(ACK)
          elsif self.headers[-1].is_hl7?
            if self.headers.size > 0
              ## commit should return the jsonified thing, if possible.
              self.headers[-1].commit
              send_data(self.headers[-1].generate_ack_success_response)
            end
          end
        end
      end
  end

  def send_enq
    puts "enq as bytes is:"
    puts ENQ.unpack('c*')
    send_data(ENQ)
  end

  def process_text(text)
      text.split("\n").each do |l|
		    line = Line.new({:text => l})
        process_type(line)
      end
  end

  def process_type(line)
      case line.type
      when "Hl7_Header"
        hl7_header = Hl7Header.new({:line => line})
        self.headers ||= []
        self.headers << hl7_header
      when "Hl7_Observation"
        hl7_observation = Hl7Observation.new({:line => line})
        self.headers[-1].patients[-1].orders[-1].results[hl7_observation.name] = hl7_observation
      when "Hl7_Patient"
        hl7_patient = Hl7Patient.new({:line => line})
        self.headers[-1].patients << hl7_patient
      when "Hl7_Order"
        hl7_order = Hl7Order.new({:line => line, :patient_id => self.headers[-1].patients[-1].patient_id})
        self.headers[-1].patients[-1].orders << hl7_order
      when "Header"
        header = Header.new({:line => line})
        self.headers ||= []
        self.headers << header
      when "Query"
        query = Query.new({:line => line})
        self.headers[-1].queries << query
      when "Patient"
        patient = Patient.new({:line => line})
        self.headers[-1].patients << patient
      when "Order"
        order = Order.new({:line => line})
        self.headers[-1].patients[-1].orders << order
      when "Result"
        result = Result.new({:line => line})
        self.headers[-1].patients[-1].orders[-1].results[result.name] = result
      when "Terminator"
        ## it didn't terminate so there was no commit being called.
        self.headers[-1].commit
      end
  end

=begin
1.STX + response + LF + ETX
2.response
3.STX + response + "L|1|N\r" + ETX 
4.response + "L|1|N\r" 
=end
  def unbind
     puts "-- someone disconnected from the echo server!"
  end

end