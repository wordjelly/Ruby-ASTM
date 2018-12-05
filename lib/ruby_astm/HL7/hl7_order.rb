require "ruby_astm/order"
class Hl7Order < Order
	def set_id(args)
		self.id = args[:patient_id]
	end
end