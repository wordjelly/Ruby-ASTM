require 'fileutils'
require 'publisher/poller'


class Pf_Lab_Interface < Poller

	ORDERS = "orders"
	BARCODES = "barcodes"
	## this has to be passed in from the poller file.
	attr_accessor :lis_security_key
	###################################################################
	##
	##
	## UTILITY METHOD FOR THE ORDER AND BARCODE HASHES ADD AND REMOVE
	##
	##
	###################################################################
	def remove_order

	end

	def remove_barcode

	end

	def add_new_order

	end

	def add_barcode

	end
	###################################################################
	##
	##
	## ENDS.
	##
	##
	###################################################################


	###################################################################
	##
	##
	## METHODS OVERRIDDEN FROM THE BASIC POLLER.
	##
	##
	###################################################################
	## @param[String] mpg : path to mappings file. Defaults to nil.
	## @param[String] credentials_path : the path to look for the credentials.json file, defaults to nil ,and will raise an error unless provided
	## @param[String] token_path : the path where the oauth token will be stored, also defaults to the path of the gem : eg. ./token.yaml - be careful with write permissions, because token.yaml gets written to this path after the first authorization.
	def initialize(mpg=nil,lis_security_key)
	    super(mpg)
	    self.lis_security_key = lis_security_key
	    AstmServer.log("Initialized Lab Interface")
	end

	def poll_LIS_for_requisition
		## your'e getting the entire orders.
		## right ?
		## so we get orders
		## we store them where ?
		## ===============================>
		## we keep a sorted set ->
		## called orders
		## in that we key them by id, and one more hash 
		## barcode -> order_id
		## etc.
		## => ==============================>

		## poll lis means it gets all the orders
		## not some specific items.
		## it doesn have the blood items.
		## so for any given test, only one thing can have priority.
		## and we can force if required, on the server side.
		## so how will it repoll ?
		## if a priority change was initiated, then 
		## this is basically going to return an orders object
		## it is going to contain the entire order.
		## and each report and which barcodes it is registered on
		## these have to be merged with the 
		## the tests hash probably contains the machine codes
		## response could be anything.
		## tests hash currently needs to look like this
		## let us say that there is more than one machine code for a given
		## lis code.
		## so that mapping is also important.
		## so where to store the order details
		## how to handle multiple tubes being polled for the same test
		## will there be priorities.
		## so we will have to have something like force_priority at lis
		## level.
		## so a given barcode may be 
		## "barcode" => [machine_code]
		## process_lis_response -> build_tests_hash -> merge_with_requisitions_hash
	end

	## only need to override this.
	## it consists of an array of 
	## results
	## with barcode(id), and results([{name:,value:}])
	## so this is not too hard
	## get the barcode ,from barcodes hash -> get the order_id, 
	## if the barcode is not there, then it has to add it to a queries array.
	## if the barcode is there -> get the order -> and create an order with just the results, and an empty report for the update.
	## and then make the update.
	def update

	end

	def poll
      	pre_poll_LIS
      	poll_LIS_for_requisition
      	update_LIS
      	post_poll_LIS
  	end

end