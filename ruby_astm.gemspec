Gem::Specification.new do |s|
  s.name        = 'ruby_astm'
  s.version     = '1.5.4'
  s.date        = '2018-11-20'
  s.summary     = "A Ruby gem to interface with Medical instruments that work on the ASTM protocol and HL7 protocol. Offers limited bidirectionality for ASTM. Bidirectionality is currently not supported for HL7"
  s.description = "This gem provides a server that can handle communication from medical instruments that send/receive information on the ASTM protocol."
  s.authors     = ["Bhargav Raut"]
  s.email       = 'bhargav.r.raut@gmail.com'
  s.files       = Dir['lib/**/**/*','lib/**/*','lib/*']
  s.homepage    = 'https://www.github/com/wordjelly/ruby_astm'
  s.license       = 'MIT'
  s.add_dependency 'eventmachine'
  s.add_dependency 'em-rubyserial'
  s.add_dependency 'activesupport','5.2.2'
  s.add_dependency 'json'
  s.add_dependency 'redis'
  s.add_dependency 'typhoeus'
  s.add_dependency 'google-api-client', '0.25.0'
  s.add_dependency 'rufus-scheduler', '3.5.2'
  s.add_dependency "rest-firebase"
  s.add_dependency "jwt"
  s.add_dependency "rake"
  s.add_dependency "retriable", '~> 3.1'

end

