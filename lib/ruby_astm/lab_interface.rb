require "active_support/all"

module LabInterface

	ACK = "\x06"
  mattr_accessor :headers
  mattr_accessor :server_signature
  mattr_accessor :server_ip
  mattr_accessor :server_port
  mattr_accessor :mapping

     
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

  def process_query_text_file(full_file_path)

  end

	def receive_data(data)
      
      byte_arr = []
      
      concat = ""
      
      data.bytes.to_a.each do |byte|
        x = [byte].pack('c*').force_encoding('UTF-8')
        if x == "\r"
          concat+="\n"
        elsif x == "\n"
          puts "new line found --- "
          concat+=x
          puts "last thing in concat."
          puts concat[-1].to_s
        else
          concat+=x
        end
      end
      

      puts "concat is:"

      puts concat.to_s

      #process_text(concat)
      
      #open('em_sample.txt', 'a') { |f|
      #  f.puts concat
      #}

      send_data(ACK)
    
  end

  def process_text(text)
		  line = Line.new({:text => text})
      process_type(line)
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
        self.headers[-1].build_responses.each do |response|
          send_data(response.bytes)
        end
        self.headers[-1].commit
      end
  end

  def unbind
     puts "-- someone disconnected from the echo server!"
  end

end