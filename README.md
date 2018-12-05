# RUBY-ASTM

Medical Laboratory Instruments work either on the ASTM Protocol or the HL7 protocol. I didn't find any gems that provide a low level API to deal with these protocols in a simple and customizable way. This gem hopes to bridge that gap.
The library provides an EventMachine Server, and several helpful classes that do nearly all of the heavy lifting.
The library is so small, that it doesn't need a Wiki. ;)
The architecture that you get with this gem is outlined in the following figure.


## How to Use

To use in a standalone ruby file:

```
gem install ruby-astm
```

Then 

```
require 'ruby-astm'
```


### Server Parameters:

Configure the server PORT and HOST_IP. This should be the same HOST_IP AND PORT that is entered into the various laboratory instruments that are going to be sending data to you.


### Database_Adapter:

The gem, basically parses incoming data, and dumps each patient order into redis. Override the __commit__ method on the __Header__ class to send the data to your own database. I have used PORO's so that there are no assumptions about databases.  



## WHAT THE JSON STRINGS LOOK LIKE:


```

{
	"machine_name" => "Whatever",
	"patients" => [
		{
			"orders" => [
				{
					"id" => "the patient id",
					"results" => [
						{
							"name" => "Blood Count",
							"value" => "10",
							"units" => "10^3 pg/ml",
							"flags" => "N",
							"dilution" => 1,
							"timestamp" => "2018-11-06T09:35:09.000+05:30"
						}
					]
				}
			]
		}
	]
}

```


## TESTED WITH INSTRUMENTS

1. Sysmex-XN550