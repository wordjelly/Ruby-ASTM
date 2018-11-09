class Header
	attr_accessor :machine_name
	attr_accessor :patients
	def initialize(line)
		fields = line.fields[4].split(/\^/)
		self.machine_name = fields[0].strip
		self.patients = []
	end

	## pushes each patient into a redis list called "patients"
	def commit
		self.patients.map{|patient| $redis.lpush("patients",patient.to_json)}
		puts JSON.pretty_generate(JSON.parse(self.to_json))
	end

	def to_json
        hash = {}
        self.instance_variables.each do |x|
            hash[x] = self.instance_variable_get x
        end
        return hash.to_json
    end

end