class Header
	attr_accessor :machine_name
	attr_accessor :patients
	def initialize(line)
		fields = line.fields[4].split(/\^/)
		self.machine_name = fields[0].strip
		self.patients = []
	end

	def commit
		puts "committing header"
	end
end