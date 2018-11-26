class Adapter

	##@param[Array] data : array of objects.
	##@return[Boolean] true/false : depending on whether it was successfully updated or not.
	## recommended structure for data.
=begin
    data = [
      {
        :id => "ARUBA",
        :results => [
          {
            :name => "TLCparam",
            :value => 10
          },
          {
            :name => "Nparam",
            :value => 23
          },
          {
            :name => "ANCparam",
            :value => 25
          },
          {
            :name => "Lparam",
            :value => 10
          },
          {
            :name => "ALCparam",
            :value => 44
          },
          {
            :name => "Mparam",
            :value => 55
          },
          {
            :name => "AMCparam",
            :value => 22
          },
          {
            :name => "Eparam",
            :value => 222
          },
          {
            :name => "AECparam",
            :value => 21
          },
          {
            :name => "BASOparam",
            :value => 222
          },
          {
            :name => "ABCparam",
            :value => 300
          },
          {
            :name => "RBCparam",
            :value => 2.22
          },
          {
            :name => "HBparam",
            :value => 19
          },
          {
            :name => "HCTparam",
            :value => 22
          },
          {
            :name => "MCVparam",
            :value => 222
          },
          {
            :name => "MCHparam",
            :value => 21
          },
          {
            :name => "MCHCparam",
            :value => 10
          },
          {
            :name => "MCVparam",
            :value => 222
          },
          {
            :name => "RDWCVparam",
            :value => 12
          },
          {
            :name => "PCparam",
            :value => 1.22322
          }
        ]
      }
    ]
=end
  ## pretty simple, if the value is not already there it will be updated, otherwise it won't be.
	def update_LIS(data)

	end

  ## will poll the lis, and store locally, in a redis sorted set the following:
  ## key => specimen_id
  ## value => tests designated for that specimen.
  ## score => time of requisition of that specimen.
  ## name of the sorted set can be defined in the class that inherits from adapter, or will default to "requisitions"
  ## when a query is sent from any laboratory equipment to the local ASTMServer, it will query the redis sorted set, for the test information.
  ## so this poller basically constantly replicates the cloud based test information to the local server.
	def poll_LIS(requisitions_hash_name="requisitions")

  end

end