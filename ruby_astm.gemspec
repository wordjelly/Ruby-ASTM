Gem::Specification.new do |s|
  s.name        = 'ruby_astm'
  s.version     = '0.0.0'
  s.date        = '2018-11-20'
  s.summary     = "A Ruby gem to interface with Medical instruments that work on the ASTM protocol"
  s.description = "This gem provides a server that can handle communication from medical instruments that send/receive information on the ASTM protocol."
  s.authors     = ["Bhargav Raut"]
  s.email       = 'bhargav.r.raut@gmail.com'
  s.files       = Dir['lib/**/*']
  #s.files       = ["lib/ruby_astm/adapter.rb","lib/ruby_astm/astm_server.rb","lib/ruby_astm/lab_interface.rb","lib/ruby_astm.rb"]
  s.homepage    =
    'https://www.github/com/wordjelly/ruby_astm'
  s.license       = 'MIT'
  
  s.add_dependency 'eventmachine'
  s.add_dependency 'em-rubyserial'
  s.add_dependency 'activesupport'
  s.add_dependency 'json'
  s.add_dependency 'redis'

end