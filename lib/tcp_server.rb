require 'fcntl'
require 'socket'
require 'server'
require 'connection'

class Reactor::TCPServer < Reactor::Server
	include Socket::Constants
	def initialize(options)
		@socket = if options[:socket]
								options[:socket]
							elsif options[:host] && options[:port] 
								::TCPServer.new(options[:host], options[:port])
							end
		
		# set the socket options
		@socket.listen(511)
		@socket.setsockopt(IPPROTO_TCP, TCP_NODELAY, 1)
		@socket.setsockopt(IPPROTO_TCP, TCP_DEFER_ACCEPT, 1) 
		@socket.fcntl(Fcntl::F_SETFL, Fcntl::O_NONBLOCK)
		super
		start		
	end

end

class Reactor::Base
	def tcp_server(options)
		options[:reactor] = self		
		Reactor::TCPServer.new(options)
	end
end
