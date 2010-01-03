require 'tcp_server'
require 'unicorn_http'
require 'rack'

class Reactor::HTTPConnection < Reactor::Connection

	attr_accessor :keepalive

	MAX_HEADER = 8 * 1024
	MAX_BODY = 8 * 1024

	LOCALHOST = '127.0.0.1'.freeze
	REMOTE_ADDR = 'REMOTE_ADDR'.freeze
	KEEP_ALIVE = 'Keep-Alive'.freeze
	CLOSE = 'Close'.freeze 

  DEFAULTS = {
    "rack.errors" => STDERR,
    "rack.multiprocess" => true,
    "rack.multithread" => false,
    "rack.run_once" => false,
    "rack.version" => [1, 0],
    "SCRIPT_NAME" => "",
  }

  # Every standard HTTP code mapped to the appropriate message.
  HTTP_CODES = Rack::Utils::HTTP_STATUS_CODES.inject({}) { |hash,(code,msg)|
    hash[code] = "#{code} #{msg}"
    hash
  }

	def post_init
		@data = ''
		@env = {}
		@parser = ::Unicorn::HttpParser.new		
		@keepalive = false
    @env[REMOTE_ADDR] = @conn === TCPSocket ? @conn.peeraddr.last : LOCALHOST
	end

	def data_received(data)
		@data << data
		if @data.length > MAX_HEADER
			# we need to log this incident
			close!
			return
		end
		if @parser.headers(@env, @data)
			# if we get here then the request headers were succssefuly parsed
			# now is a good time to check for keep alive
			# but we have the connection in the connections list anyway
			handle_http_request
		end
	end

	def handle_http_request
			# check if file exists
			f = File.open(@env['REQUEST_PATH'].sub("/",''))
			@env['Content-Length'] = f.stat.size
			send_http_response(200, @env, @env['REQUEST_PATH'].sub("/",''))	
			f.close			
 	end

	# we will attempt to compose the headers and the body
	# if they both fit within the chunk size then we will
	# attempt to send them right away, else we will send them
	# off the current tick via the reactor
	def send_http_response(status, headers, body)
		headers['Date'] = Time.now.httpdate
		headers['Status'] = HTTP_CODES[status.to_i] || status
		headers['Connection'] = @keepalive ? KEEP_ALIVE : CLOSE
		response = "HTTP/1.1 #{status}\r\n"
		headers.each do |key, value|
      response << if value =~ /\n/
										(value.split(/\n/).map!{|v| "#{key}: #{v}\r\n" }).join('')
									else
										"#{key}: #{value}\r\n"
									end
    end
		response << "\r\n"
		#unless body.empty?
			# we have a body let's grab a chunk 
			# from it and add it to the response
			# ...
			# but how do I get a chunk?
			# Rack only defines #each on the body
			# should I use an external iterator? (yikes!)
		#end	
		#response << body
		write(response)
		stream(body)		
		finish
 	end

	def finish
		close unless @keepalive	
	end

end
