require 'reactor'
require 'http_server'

reactor = Reactor::Base.new
server = Reactor::HTTPServer.new({:host => '0.0.0.0', :port => '8000', :reactor => reactor}) 
reactor.run
