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
  mattr_accessor :server_signature
  mattr_accessor :server_ip
  mattr_accessor :server_port
  mattr_accessor :mapping
  mattr_accessor :respond_to_queries
  

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
      process_text(line)
    end
  end

  def terminator
    "4L|1|N\r"
  end

  def checksum(input)
    strString = input
    checksum = strString.sum
    #puts checksum
    b = checksum.to_s(8)
    strCksm = b[-2..-1]
    if strCksm.length < 2 
      for i in strString.length..1
         strCksm = "0" + strCksm
      end
    end
    puts strCksm
    strCksm
  end

	def receive_data(data)
      
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
      puts concat.to_s
      process_text(concat)      
      
      if data.bytes.to_a[0] == 4
        puts "sent ENQ"
        send_data(ENQ)
      elsif data.bytes.to_a[0] == 6
        ## send the last header responses.
        puts " --- GOT ACK --- "
        response = STX + "1H|\`^&||||||||||P|E 1394-97|#{Time.now.strftime("%Y%m%d%H%M%S")}\r" + terminator + ETX + checksum("1H|\`^&||||||||||P|E 1394-97|#{Time.now.strftime("%Y%m%d%H%M%S")}\r" + terminator) + "\r"
        response = response.bytes.to_a
        response << 10
        send_data(response.pack('c*'))

=begin
        self.headers[-1].build_responses.each do |response|
          final_resp = STX + response + terminator + ETX + "99\r" 
          final_resp_arr = final_resp.bytes.to_a
          final_resp_arr << 10
          puts final_resp_arr.to_s
          send_data(final_resp_arr.pack('c*')) 
        end
=end
      else
        ## send the header 
        puts "--------- SENT ACK -----------"
        send_data(ACK)
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