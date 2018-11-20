class Frame
  
  attr_accessor :machine_model
  attr_accessor :astm_version
  attr_accessor :records

  def initalize(args)
  	self.records = []
  	super(args)
  end

  def self.is_start_frame?(l)
 	line_without_control_char = l[1..-1]
 	return line_without_control_char =~ /\d+H/
  #k = l[0].bytes
	#if k.to_s == "[5]"
	#	puts "ENQ"
	#end
  end

  def self.is_end_frame?(line)
  	
  end

end