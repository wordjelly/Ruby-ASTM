class RealTimeDb

	SITE_URL = ENV["SITE_URL"]
	SECRET = ENV["SECRET"]
	attr_accessor :connection
	attr_accessor :work_allotment_hash
	WORK_TYPES = {
		"IMMUNO" => "",
		"BIOCHEM" => "",
		"BIOCHEM-EXL" => "",
		"BIOCHEM-ELECTROLYTE" => "",
		"HEMAT" => "",
		"URINE" => "",
		"OUTSOURCE" => ""
	}

	## @param[Hash] work_allotment_hash :
	## key => one of the work types
	## value => name of a worker
	def initialize(work_allotment_hash)
		self.connection = RestFirebase.new :site => SITE_URL,
                     :secret => SECRET
        self.work_allotment_hash = work_allotment_hash || WORK_TYPES
	end


	## we pass the real_time_data instance into the 

	def assign_test(barcode,tests,mappings)
		## so do we get the name of the worker.
		inverted_mappings = {}
		mappings.keys.each do |machine_code|
			lis_code = mappings[machine_code][LIS_CODE]
			inverted_mappings[lis_code] = mappings[machine_code]
		end
		worker_hash = {}
		tests.each do |lis_code|
			worker_name = "NO_ONE"
			unless inverted_mappings[lis_code].blank?
				test_type = inverted_mappings[lis_code]["TYPE"]
				worker_name = self.work_allotment_hash[test_type]
			end
			worker_hash[worker_name] ||= []
			worker_hash[worker_name] << lis_code
		end
		worker_hash.keys.each do |worker_name|
			#self.connection.post("lab/work/#{worker_name}", :tests => worker_hash[worker_name], :barcode => barcode, :timestamp => Time.now.to_i)
		end
	end
	
end