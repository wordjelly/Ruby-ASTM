module NephModule
	include PfModule

	def self.included base
    	base.extend ClassMethods
  	end

  	def receive_data(data)
  		byte_arr = data.bytes.to_a
  		puts byte_arr.to_s
  		if ((byte_arr[-1] == 10) || (byte_arr[-1] == 5))
  			puts "gave ack"
    		send_data(ACK)
    	end  
=begin
	    begin


	      self.data_buffer ||= ''

	      #puts "incoming data bytes."

	      concat = ""
	      
	   
	      byte_arr = data.bytes.to_a
	      
	      self.test_data_bytes ||= []
	      
	      self.data_bytes ||= []

	      self.test_data_bytes.push(byte_arr)

	      self.data_bytes.push(byte_arr)

	    
	      concat = pre_process_bytes(byte_arr,concat)
	 
	      #puts "concat is:"
	      
	      #puts concat.to_s
	      
	      self.data_buffer << concat

	      ## if the last byte is EOT, then call process text.
	      ## inside that split by line and process one at a time.
	      ##process_text(concat)   
	      #puts "data bytes -1: #{self.data_bytes[-1]}"
	      #puts "data bytes 0: #{self.data_bytes[0]}"   
	      #if self.data_bytes[0] == ELECTROLYTE_START
	      #self.process_electrolytes(self.data_bytes) 
	      #end

	      if data.bytes.to_a[-1] == 4
	        #puts "GOT EOT --- PROCESSING BUFFER, AND CLEARING WILL DO NOTHING"
	        process_text(self.data_buffer)
	        root_path = File.dirname __dir__
	        #puts "root path #{root_path}"
	        #IO.write((File.join root_path,'../test','resources','d10_error.txt'),self.test_data_bytes.to_s)
	        #puts self.test_data_bytes.flatten.to_s
	        self.data_buffer = ''
	        unless self.headers.blank?
	          if self.headers[-1].queries.blank?
	            #puts "no queries in header so sending ack after getting EOT and processing the buffer"
	            #send_data(ACK)
	          else
	            #puts "sending ENQ"
	            #send_data(ENQ)
	          end
	        else
	          #puts "sending catch all --------------- ACK --------------"
	          #send_data(ACK)
	        end
	        SEND_DATA(EOT)
	      elsif data.bytes.to_a[0] == 6
	        puts "GOT ACK --- GENERATING RESPONSE"
	        unless self.headers.blank?
	          header_responses = self.headers[-1].build_one_response({machine_name: self.headers[-1].machine_name})
	          ## if no queries then, we have to send ack.
	          if header_responses.blank?
	            #puts "sending ACK since there are no queries in the header"
	            send_data(ACK)
	          end
	          header_responses.each_with_index {|response,key|
	            message_checksum = checksum(response + terminator + ETX)
	            final_resp = STX + response + terminator + ETX + message_checksum + "\r" 
	            final_resp_arr = final_resp.bytes.to_a
	            final_resp_arr << 10
	            if (self.headers[-1].response_sent == false)
	              #puts "sending the  data as follows----------------------------------------------"
	              #puts "response sent is:"
	              #puts self.headers[-1].response_sent
	              #puts final_resp_arr.pack('c*').gsub(/\r/,'\n')
	              send_data(final_resp_arr.pack('c*')) 
	              self.headers[-1].response_sent = true if (key == (header_responses.size - 1))
	            else
	              #puts "sending EOT"
	              send_data(EOT)
	            end
	          }
	        else
	          #puts "NO HEADERS PRESENT --- "
	        end
	      elsif data.bytes.to_a[0] == 255
	        puts  " ----------- got 255 data -----------, not sending anything back. "
	      elsif data.bytes.to_a[0] == 5
	      	puts "ACKING ON ENQ"
	        send_data(ACK)
	      else
	        puts "ACKING"
	        send_data(ACK)
	      end

	    rescue => e
	      
	      #self.headers = []
	      AstmServer.log("data was: " + self.data_buffer + "error is:" + e.backtrace.to_s)
	      #send_data(EOT)
	    end
=end
  	end
 	
end