module SiemensDimensionExlModule

	include LabInterface

	def self.included base
    	base.extend ClassMethods
  	end

  	FS = "\x1C"
    ACK_REPLACE = "ACK-"
    FS_REPLACE = "|"
    STX_REPLACE = "STX-"
    ETX_REPLACE = "-ETX"

    REPLACEMENT_HASH = {
      ETX => ETX_REPLACE,
      STX => STX_REPLACE,
      FS => FS_REPLACE,
      ACK => ACK_REPLACE
    }



  	def pre_process_bytes(byte_arr,concat)

  	  puts "this is the overridden method"
      puts byte_arr.to_s
      puts byte_arr.pack('c*').force_encoding('UTF-8')

      indices_to_delete = is_mid_frame_end?(byte_arr)
      puts "indices to delete"
      puts indices_to_delete.to_s

      if self.mid_frame_end_detected == true
        puts "deletected mid fram is true, so deleting first byte before delete"
        puts byte_arr.to_s
        byte_arr = byte_arr[1..-1]
        puts "after deleteing"
        puts byte_arr.to_s
        self.mid_frame_end_detected = false
      end

      unless indices_to_delete.blank?
        if byte_arr[(indices_to_delete[-1] + 1)]
          puts "before deleting frame number "
          puts byte_arr.to_s
          byte_arr.delete_at((indices_to_delete[-1] + 1))
          puts "after deleting"
          puts byte_arr.to_s
        else
          self.mid_frame_end_detected = true
        end
      end
      puts "byte arr before reject"
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

    def message_to_string
      string = self.data_bytes.flatten.pack('c*') 
      REPLACEMENT_HASH.keys.each do |k|
        string.gsub!(/#{k}/,REPLACEMENT_HASH[k])
      end
      puts "BYTE ARRAY"
      puts "message ends #{self.data_bytes.flatten}"
      puts "HUMAN READABLE MESSAGE"
      puts string
    end

  	def message_ends?
  		x = self.data_bytes.flatten[-1] == 3
  		if x == true
        message_to_string
  		end
  		x
  	end

    SERUM = "1"
    PLASMA = "2"
    ROUTINE_PRIORITY = "0"

    TYPE = "D"
    SAMPLE_CARRIER_ID = "0"
    LOADLIST_ID = "0"
    TRANSACTION = "A"
    PATIENT_ID = ""
    BARCODE = ""
    SAMPLE_TYPE = SERUM
    LOCATION = "0"
    PRIORITY = ROUTINE_PRIORITY
    NUMBER_OF_CUPS = "1"
    CUP_POSITION_FIELDS = "**"
    DILUTION = "1"  
    NUMBER_OF_TESTS = ""
    TESTS = ""


    ## => <STX>D<FS>0<FS>0<FS>A<FS>Doe,John<FS>012345<FS>2<FS>
    ## <FS>0<FS>1<FS>**<FS>1<FS>2<FS>BUN<FS>CREA<FS>F5<ETX>
    def response_components 
=begin
D <FS>
0 <FS>
0 <FS>
A <FS>
Doe,John <FS>
012345 <FS>
2 <FS>
  <FS>
0 <FS>
1 <FS>
**<FS>
1 <FS>
2 <FS>
BUN <FS>
CREA<FS>

--------
D|
0|
0|
A|
doggy|
0000011687|
1|
0|
0|
1|
0|
1|
1|
TP
=end
      {
        "TYPE" => TYPE,
        "SAMPLE_CARRIER_ID" => SAMPLE_CARRIER_ID,
        "LOADLIST_ID" => LOADLIST_ID,
        "TRANSACTION" => TRANSACTION,
        "PATIENT_ID" => "dog2",
        "BARCODE" => BARCODE,
        "SAMPLE_TYPE" => "2",
        "LOCATION" => "",
        "PRIORITY" => PRIORITY,
        "NUMBER_OF_CUPS" => NUMBER_OF_CUPS,
        "CUP_POSITION_FIELDS" => "**",
        "DILUTION" => DILUTION,
        "NUMBER_OF_TESTS" => NUMBER_OF_TESTS,
        "TESTS" => TESTS
      } 
    end


    # STX-|0|1|0|A||0000010383|0|0|1||1|1|GLUC|67-ETX
    def response(barcode,machine_codes)
      start = STX 
      resp = ""
      response_components.keys.each do |component|
      
        if component == "BARCODE"
          resp += barcode
        elsif component == "PATIENT_ID"
          resp += "dragon"
        elsif component == "NUMBER_OF_TESTS"
          resp += machine_codes.size.to_s
        elsif component == "TESTS"
          resp += machine_codes.join(FS)
        else
          resp += response_components[component]
        end
        resp += FS
      end
      resp = "D#{FS}0#{FS}0#{FS}A#{FS}VILAS KARGUDE#{FS}#{barcode}#{FS}#{SERUM}#{FS} #{FS}0#{FS}1#{FS}**#{FS}1#{FS}1#{FS}GLUC#{FS}"
      #resp.force_encoding("UTF-8")
      #resp = "D#{FS}0#{FS}0#{FS}A#{FS}VISHAL RAJARAM GHOLAP#{FS}1130043201#{FS}1#{FS} #{FS}0#{FS}1#{FS}**#{FS}1#{FS}1#{FS}GLUC#{FS}"
      message_checksum = checksum(resp)
      #message_checksum = "04"
      final = start + resp + message_checksum + ETX + "\n"
      
=begin
<STX>
  D <FS>
  0 <FS>
  0 <FS>
  A <FS>
  Doe,John <FS>
  012345 <FS>
  2 <FS>
    <FS>
  0 <FS>
  1 <FS>
  **<FS>
  1 <FS>
  2 <FS>
  BUN <FS>
  CREA<FS>
  F5
  <ETX>
=end
      #puts "response is: "
      #puts final.to_s
      #string = final 
      #final = "#{STX}0#{FS}0#{FS}0#{FS}A#{FS}Doe,John#{FS}0000011687#{FS}2#{FS}
#{FS}0#{FS}1#{FS}**#{FS}1#{FS}2#{FS}GLUC#{FS}TP#{FS}DF#{ETX}" + "\n"
      #final = "#{STX}0#{FS}0#{FS}0#{FS}A#{FS}DoeJohn#{FS}0000011050#{FS}2#{FS}#{FS}0#{FS}1#{FS}**#{FS}1#{FS}1#{FS}GLUC#{FS}F5#{ETX}" + "\n"
      #final = "#{STX}#{ETX}" + "\n"
      #final = "#{STX}D#{FS}0#{FS}0#{FS}A#{FS}Doe,John#{FS}012345#{FS}2#{FS}#{FS}0#{FS}1#{FS}**#{FS}1#{FS}2#{FS}BUN#{FS}CREA#{FS}F5#{ETX}" + "\n"
      string = final
      puts final.bytes.to_a.to_s
      #REPLACEMENT_HASH.keys.each do |k|
      #  string.gsub!(/#{k}/,REPLACEMENT_HASH[k])
      #end
      #puts "HUMAN READABLE MESSAGE"
      #puts string
      send_data(final.bytes.to_a.pack('c*'))

    end

    def is_result?
      x = ((self.data_bytes.flatten[2] == 82) || (self.data_bytes.flatten[2] == 67) || (self.data_bytes.flatten[3] == 67) || (self.data_bytes.flatten[3] == 82) || (self.data_bytes.flatten[1] == 67) || (self.data_bytes.flatten[1] == 82))
      if x == true
        puts "its a result"

      end
      x
    end
    
    ## => 
    def is_query?
      x = ((self.data_bytes.flatten[2] == 73))
      if x == true
        puts "its a query"

      end
      x
    end

    def is_position_accept?
      x = ((self.data_bytes.flatten[2] == 77) || ((self.data_bytes.flatten[3] == 77)))
      if x == true
        puts "its a position accept"

      end
      x
    end

    def acknowledge_result
      #<STX>M<FS>A<FS><FS>E2<ETX>
      puts "acknowledging result."
      resp = STX + "M" + FS + "A" + FS + FS + "E2" + ETX + "\n" 
      send_data(resp.bytes.to_a.pack('c*'))
    end

    def acknowledge_routine
      #<STX>M<FS>A<FS><FS>E2<ETX>
      puts "acknowledging result."
      resp = ACK + "\n" 
      send_data(resp.bytes.to_a.pack('c*'))
    end
  
  	def enq?
  		self.data_bytes.flatten[-1] == 5
  	end

  	def acknowledge
  		resp = ACK 
  		send_data(ACK)
  	end

  	def no_request(pass=false)
      if pass.blank?
  		  resp = STX + "N" + FS + "6A" + ETX + "\n" 
  		  send_data(resp.bytes.to_a.pack('c*'))
      else
        resp = STX + "N" + FS + "6B" + ETX + "\n" 
        send_data(resp.bytes.to_a.pack('c*'))
      end
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
          if is_query?
            acknowledge
            #acknowledge
            #acknowledge
            #acknowledge
            #sleep(1)
            response("0000010836",["TP"])
            #acknowledge
          elsif is_result?
            acknowledge
            sleep(1)
            acknowledge_result
          elsif is_position_accept?
            acknowledge
          else
            acknowledge
            #acknowledge
            #response("0000021657",["MG"])

            no_request(false)
            #acknowledge
            #response("0000012295",["TP"])

           
            #sleep(1)
            #response(('%010d' % rand(10 ** 5)),["GLUC"])
          end
          
          self.data_bytes = []
	      end

	    
	    rescue => e
	      
	      #self.headers = []
	      AstmServer.log("data was: " + self.data_buffer + "error is:" + e.backtrace.to_s)
	      #send_data(EOT)
	    end

  	end

end