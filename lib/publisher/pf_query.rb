class PfQuery < Query

	def get_tests(sample_id)
		tests = []
		if barcode_entry = $redis.hget(Pf_Lab_Interface::BARCODES,sample_id)
			barcode_entry = JSON.parse(barcode_entry)
			tests = barcode_entry[Pf_Lab_Interface::MACHINE_CODES]
		end
		puts "--------- TESTS RETURNED FROM PFQUERY -> #{tests}"
		tests
	end

end