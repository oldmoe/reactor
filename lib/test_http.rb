require './reactor'
require 'http_connection'

reactor = Reactor::Base.new
server = Reactor::TCPServer.new({:host => '0.0.0.0', :port => '8000', :reactor => reactor, :handler => Reactor::HTTPConnection}) 
reactor.run
