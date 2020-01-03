class PfDownloadException < StandardError
	def initialize(message)
		super(message)
		AstmServer.log(message)
	end
end