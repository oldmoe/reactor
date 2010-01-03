require 'fcntl'
require 'socket'
require 'server'
require 'connection'

class Reactor::TCPServer < Reactor::Server

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

	def stream(connection, io)
	end

	def stream_file(connection, io)
	end	

end

class Reactor::Base
	def tcp_server(options)
		options[:reactor] = self		
		Reactor::TCPServer.new(options)
	end
end
