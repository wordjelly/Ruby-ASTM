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

	##@param[Array] data : array of objects.
	##@return[String] response : json string of the response from the LIS.
	def query_LIS(data)

	end

end