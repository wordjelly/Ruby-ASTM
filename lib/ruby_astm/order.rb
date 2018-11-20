class Order
	## => patient id.
	attr_accessor :id
	## => key : result name.
	## => value : result object
	attr_accessor :results
	def initialize(line)
		## for the em-200, the specimen id is in in the second field.
		## also the specimen id comes first, followed by the position of the specimen.
		if line.fields[2]
			line.fields[2].strip.scan(/(?<specimen_id>[^\^]+)/) { |specimen_id|
				self.id ||= specimen_id
			}
=begin
			line.fields[2].strip.scan(/(?<specimen_id>.+)\^(?<position>.+)/) {|specimen_id, position|
				self.id = specimen_id.strip
			}
=end
		elsif line.fields[3]
			## for the sysmex xn-550 this is the regex.
			line.fields[3].strip.scan(/(?<tube_rack>\d+\^)+(?<patient_id>.+)\^/) { |tube_rack,patient_id|  self.id = patient_id.strip}
		end
		self.results = {}
	end
end