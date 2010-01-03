require 'rbtree'
require 'reactor'

class Reactor::Server

	CONNECTION_TIMEOUT = 120 # 2 minutes default timeout
	TCP_DEFER_ACCEPT = 9
	TCP_CORK = 3

	attr_reader :connections, :timeout
	
	def initialize(options)
		@connections = {}
		@reactor = options[:reactor]
		@handler_class = options[:handler]
		@timeout = (options[:timeout] || CONNECTION_TIMEOUT) * 1000 # timeout in milliseconds
	end

	def start
		@reactor.attach(:read, @socket) do |socket, reactor|
			begin
				loop do
					conn = socket.accept
					begin
						request_handler = @handler_class.new(conn, reactor)
					rescue Exception => e
						puts e # we need to log those errors, may be we are being DDoSed?
						puts e.backtrace		
						request_handler.close(false)	# close the request now 
					end
				end
			rescue Exception => e
			end
		end
		me = self
		@reactor.add_periodical_timer(1) do
			if !me.connections.empty?
				time = Time.now
				# loop on all the connections
				# and remove those that timed out
				while time - me.connections.first.last_active	>= me.timeout
					id, conn = *(me.connections.shift)
					conn.close(false)
				end
			end
		end
	end

	def stop!
		stop
		@socket.close
		@connections = {}
	end

	def stop
		@reactor.detach(:read, @socket)
	end

end
