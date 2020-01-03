module SiemensAbgElectrolyteModule

	include LabInterface

	def self.included base
    	base.extend ClassMethods
  	end


	SIEMENS_ELECTROLYTE_END = [10,10,10,10]
	ELECTROLYTE_START = [45, 45, 45, 32]
	SIEMENS_ELEC_ABG_RESULTS_HASH = "SIEMENS_ELEC_ABG_RESULTS_HASH"

	attr_accessor :current_text_segment

	def get_po2
		m = []
		self.current_text_segment.scan(/pO2\s+(?<k>(\d+)(\.\d)*)(\^|v)?\s+mmHg/) do |l|
	      n = Regexp.last_match
	      m << n[:k].to_s
	    end
	    raise "more than one result #{m.to_s}" if (m.size > 1)
	    return m[0] if m.size == 1
	    return nil
	end

	def get_pco2
		m = []
		self.current_text_segment.scan(/pCO2\s+(?<k>(\d+)(\.\d)*)(\^|v)?\s+mmHg/) do |l|
	      n = Regexp.last_match
	      m << n[:k].to_s
	    end
	    raise "more than one result #{m.to_s}" if (m.size > 1)
	    return m[0] if m.size == 1
	    return nil
	end

	def get_ph
		m = []
		self.current_text_segment.scan(/pH\s+(?<k>(\d+)[\.\d]*)(\^|v)?\s+$/) do |l|
	      n = Regexp.last_match
	      m << n[:k].to_s
	    end
	    raise "more than one result #{m.to_s}" if (m.size > 1)
	    return m[0] if m.size == 1
	    return nil
	end

	def get_na
		m = []
		self.current_text_segment.scan(/Na\+\s+(?<k>(\d+)[\.\d]*)(\^|v)?\s+mmol\/L/) do |l|
	      n = Regexp.last_match
	      m << n[:k].to_s
	    end
	    raise "more than one result #{m.to_s}" if (m.size > 1)
	    return m[0] if m.size == 1
	    return nil
	end

	def get_k
		m = []
		self.current_text_segment.scan(/K\+\s+(?<k>(\d+)[\.\d]*)(\^|v)?\s+mmol\/L/) do |l|
	      n = Regexp.last_match
	      m << n[:k].to_s
	    end
	    raise "more than one result #{m.to_s}" if (m.size > 1)
	    return m[0] if m.size == 1
	    return nil
	end

	def get_cl
		m = []
		self.current_text_segment.scan(/Cl\-\s+(?<k>(\d+)[\.\d]*)(\^|v)?\s+mmol\/L/) do |l|
	      n = Regexp.last_match
	      m << n[:k].to_s
	    end
	    raise "more than one result #{m.to_s}" if (m.size > 1)
	    return m[0] if m.size == 1
	    return nil
	end

	def get_patient_id
		m = []
		self.current_text_segment.scan(/Patient\s+ID\s+(?<k>\d+)$/) do |l|
	      n = Regexp.last_match
	      m << n[:k].to_s
	    end
	    raise "more than one result #{m.to_s}" if (m.size > 1)
	    return m[0] if m.size == 1
	    return nil
	end

	## @param[String] barcode : the barcode
	## @param[Result] result  : result_object
	def add_result?(barcode,result)
		puts "Came to add result"
		return true if $redis.hget(SIEMENS_ELEC_ABG_RESULTS_HASH,barcode).blank?
		existing_results = JSON.parse($redis.hget(SIEMENS_ELEC_ABG_RESULTS_HASH,barcode))
		if existing_results[result.name].blank?
			return true
		elsif existing_results[result.name] != result.value
			return true
		end
		false
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
	    
	    self.headers ||= [Header.new]
	    concat.split("--------------------------------").each do |record|

	    	self.current_text_segment = record
	    	if patient_id = get_patient_id
	    		self.headers[-1].patients ||= []
	    		p = Patient.new
	    		p.patient_id = patient_id
	    		p.orders ||= []
	    		o = Order.new
	    		o.id = patient_id
	    		o.results ||= {}
	    		if sodium = get_na
	    			r = Result.new
	    			r.name = "SNATRIUM"
	    			r.report_name = "Serum Electrolytes"
	    			r.value = sodium
	    			r.units = "mmol/L"
	    			r.timestamp = Time.now.to_i
	    			o.results["SNATRIUM"] = r if add_result?(patient_id,r)
	    		end

	    		if potassium = get_k
	    			r = Result.new
	    			r.name = "SPOTASSIUM"
	    			r.report_name = "Serum Electrolytes"
	    			r.value = potassium
	    			r.units = "mmol/L"
	    			r.timestamp = Time.now.to_i
	    			o.results["SPOTASSIUM"] = r if add_result?(patient_id,r)
	    		end

	    		if chloride = get_cl
	    			r = Result.new
	    			r.name = "SCHLORIDE"
	    			r.report_name = "Serum Electrolytes"
	    			r.value = chloride
	    			r.units = "mmol/L"
	    			r.timestamp = Time.now.to_i
	    			o.results["SCHLORIDE"] = r if add_result?(patient_id,r)
	    		end
	    		
	    		if ph = get_ph
	    			r = Result.new
	    			r.name = "pH"
	    			r.report_name = "ABG"
	    			r.value = ph
	    			r.units = "mmol/L"
	    			r.timestamp = Time.now.to_i
	    			o.results["pH"] = r if add_result?(patient_id,r)
	    		end
	    		
	    		if po2 = get_po2
	    			r = Result.new
	    			r.name = "po2"
	    			r.report_name = "ABG"
	    			r.value = po2
	    			r.units = "mmHg"
	    			r.timestamp = Time.now.to_i
	    			o.results["po2"] = r if add_result?(patient_id,r)
	    		end
	    		
	    		if pco2 = get_pco2
	    			r = Result.new
	    			r.name = "pco2"
	    			r.report_name = "ABG"
	    			r.value = pco2
	    			r.units = "mmHg"
	    			r.timestamp = Time.now.to_i
	    			o.results["pco2"] = r if add_result?(patient_id,r)
	    		end
	    		
	    		unless o.results.blank?
	    			p.orders << o
	    			$redis.hset(SIEMENS_ELEC_ABG_RESULTS_HASH,patient_id,JSON.generate(o.results_values_hash))
	    			self.headers[-1].patients = [p]
	    		end

	    	end
	    end

	    if self.headers.size > 0
            self.headers[-1].commit
            clear
        end

	end

	def process_text_file(full_file_path)
		k = IO.read(full_file_path)
		process_electrolytes(k.bytes)
	end

	def clear
		self.data_buffer = ''
		self.test_data_bytes = []
		self.data_bytes = []
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