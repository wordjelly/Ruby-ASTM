class SiemensAbgElectrolyteServer < AstmServer

	def get_po2

	end

	def get_pco2

	end

	def get_ph

	end

	def get_na

	end

	def get_k

	end

	def get_cl

	end

	def get_header

	end
	## we override the lab interface methods
	## and we don't pollute the lab interface itself.
	## as this is a custom analyzer.
	## @param[Array] : 
  	## [[bytes],[bytes]....]
  	def process_electrolytes(data_bytes)
	    #puts "came to process electrolytes_plain_text"
	    byte_arr = data_bytes.flatten
	    #puts "the end part of the arr is"
	    return if byte_arr[-4..-1] != SIEMENS_ELECTROLYTE_END
	    self.data_bytes = []
	    concat = ""
	    byte_arr.each do |byte|
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
	    ## nwo write concat to file
	    ## File.open("electrolytes_plain_text.txt", 'a+') { |file| file.write(concat) }
	    ## Header
	    ## Patient
	    ## Order
	    ## Result
	    ## Terminator

	    ## GET PO2
	    concat.scan(/pCO2\s+(?<pco>(\d+)(\.\d)*)(\^|v)?\s+mmHg/) do |k|
	      n = Regexp.last_match
	      puts n[:pco].to_s
	    end

	    ## GET PCO2
	    concat.scan(/pO2\s+(?<po>(\d+)(\.\d)*)(\^|v)?\s+mmHg/) do |k|
	      n = Regexp.last_match
	      puts n[:po].to_s
	    end

	    ## GET PH

	    ## GET NA+

	    ## GET K+

	    ## GET CL-

	    ## GET PATIENT_ID

	    ## GET DATE AND TIME

	    start_measure = false
	    
	    concat.split(/\n/).each do |line|
	      if line =~ /348\-D718/
	        header = Header.new({:line => line})
	        self.headers ||= []
	        self.headers << header
	      elsif line =~ /\-{32}/
	      elsif line =~ /Patient\s+ID/
	      elsif line =~ /Measured/
	      elsif line =~ /outside ref/
	      else
	      end
	    end

	    ## so we can do this.

	end

	def receive_data(data)
      

	    begin


	      	self.data_buffer ||= ''

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
		    self.process_electrolytes(self.data_bytes) 
		    #end
=begin
	      	if data.bytes.to_a[-1] == 4
		        puts "GOT EOT --- PROCESSING BUFFER, AND CLEARING."
		        process_text(self.data_buffer)
		        #root_path = File.dirname __dir
		        #puts "root path #{root_path}"
		        #IO.write((File.join root_path,'test','resources','roche_multi_frame_bytes.txt'),self.test_data_bytes.to_s)
		        #puts self.test_data_bytes.flatten.to_s
		        self.data_buffer = ''
		        unless self.headers.blank?
		          if self.headers[-1].queries.blank?
		            #puts "no queries in header so sending ack after getting EOT and processing the buffer"
		            send_data(ACK)
		          else
		            #puts "sending ENQ"
		            send_data(ENQ)
		          end
		        else
		          puts "sending catch all --------------- ACK --------------"
		          send_data(ACK)
		        end
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
	      	else
		        #unless self.data_buffer.blank?
		        #  puts self.data_buffer.gsub(/\r/,'\n').to_s
		        #end
		        ## send the header 
		        #puts "--------- SENT ACK -----------"
		        ## strip non utf 8 characters from it.
		        self.data_buffer.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
		        if self.data_buffer =~ /MSH\|/
		          #puts " -------------- HEADERS ARE BLANK WITH HL7, sending ack. ------------ "
		          process_text(self.data_buffer)
		          self.data_buffer = ''
		          if self.headers.size > 0
		            self.headers[-1].commit
		            send_data(self.headers[-1].generate_ack_success_response)
		          end
		        else
		          #puts " -------------- HEADERS ARE BLANK NOT HL7, sending ack. ------------ "
		          send_data(ACK)
		        end
	      	end
=end
	    rescue => e
	      
	      #self.headers = []
	      AstmServer.log("data was: " + self.data_buffer + "error is:" + e.backtrace.to_s)
	      #send_data(EOT)
	    end

  	end


end