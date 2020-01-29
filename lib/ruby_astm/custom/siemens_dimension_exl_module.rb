module SiemensDimensionExlModule

	include LabInterface

	def self.included base
    	base.extend ClassMethods
  	end

  	FS = "\x1C"

  	def pre_process_bytes(byte_arr,concat)

  	  puts "this is the overridden method"
      puts byte_arr.to_s

      indices_to_delete = is_mid_frame_end?(byte_arr)
      #puts "indices to delete"
      #puts indices_to_delete.to_s

      if self.mid_frame_end_detected == true
        #puts "deletected mid fram is true, so deleting first byte before delete"
        #puts byte_arr.to_s
        byte_arr = byte_arr[1..-1]
        #puts "after deleteing"
        #puts byte_arr.to_s
        self.mid_frame_end_detected = false
      end

      unless indices_to_delete.blank?
        if byte_arr[(indices_to_delete[-1] + 1)]
          #puts "before deleting frame number "
          #puts byte_arr.to_s
          byte_arr.delete_at((indices_to_delete[-1] + 1))
          #puts "after deleting"
          #puts byte_arr.to_s
        else
          self.mid_frame_end_detected = true
        end
      end
      #puts "byte arr before reject"
      byte_arr = byte_arr.reject.with_index{|c,i|  indices_to_delete.include? i}
      

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

      concat

  	end

  	def message_ends?
  		x = self.data_bytes.flatten[-1] == 3
  		if x == true
  			puts "message ends #{self.data_bytes.flatten}"
  			self.data_bytes = []
  		end
  		x
  	end

  	def enq?
  		self.data_bytes.flatten[-1] == 5
  	end

  	def acknowledge
  		resp = ACK
  		send_data(ACK)
  	end

  	def no_request
  		resp = STX + "N" + FS + "6A" + ETX + "\n" 
  		send_data(resp.bytes.to_a.pack('c*'))
  	end



	def receive_data(data)
      

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
	      
	      self.data_buffer << concat


	      if message_ends?
	      	acknowledge
	      	no_request
	      end

	    
	    rescue => e
	      
	      #self.headers = []
	      AstmServer.log("data was: " + self.data_buffer + "error is:" + e.backtrace.to_s)
	      #send_data(EOT)
	    end

  	end

end