module Reactor
  # A small, fast, pure Ruby reactor library
  #
  # Has the following features:
  #
  #  - Pure Ruby, no compilation involved
  #  - Attach/detach IO objects for readability and writability notifications
  #  - Add blocks of code that get executed after some time
  #  - Multiple reactors can co-exist (each in a separate thread of course)
  #
  # Lacks the following features: 
  #
  #  - No Epoll or Kqueue support since it relies on Ruby's IO.select
  #  - No way to cancel timers yet
  #  - Timers need to be more efficient, currently firing operation is O(n)
  #  - While you can have several reactors in several threads you cannot manipulate
  #    a single reactor from multiple threads.
  # 
  # Rationale
  #
  #  - Reactor libraries are re-implementing every bit of Ruby, 
  #    I would like to see that effort got to Ruby and its standard library 
  #  - I needed better integration with some Ruby built in classes.
  #  - Some people consider using EventMachine with Ruby as cheating!
  #
  # Example TCP server (an echo server)
  #
  # require 'reactor'
  # require 'socket'
  #
  # reactor = Reactor::Base.new
  # server = TCPServer.new("0.0.0.0",8080)
  #
  # reactor.attach(:read, server) do |server|
  #   connection = server.accept
  #   connection.write(connection.read)
  #   connection.close
  # end   
  #
  # reactor.run # blocking call, will run for ever (no signal handling currently)  
  # 
  # You can see a working example by running "ruby reactor.rb"
  class Base
    # Initializes a new reactor object
    def initialize
      @selectables = {:read => {:dirty=> false, :ios => {}, :callbacks => {}, :io_list => []}, 
                       :write=> {:dirty=> false, :ios => {}, :callbacks => {}, :io_list => []}}
      @next_procs, @timers, @running = [], {}, false
    end
    
    # Starts the reactor loop
    #
    # If a block is given it is run and the reactor itself is sent as a parameter
    # The block will be run while the reactor is in the running state but before
    # the actual loop.
    # 
    # Each run of the loop will fire all expired time objects and will wait a few
    # melliseconds for notifications on the list of IO objects, if any occurs
    # the corresponding callbacks are fired and the loop resumes, otherwise it resumes
    # directly
    def run
      @running = true
      yield self if block_given?
      loop do
        break unless @running
        while proc = @next_procs.shift
          proc.call
        end
        t = Time.now
        @timers.each_key.select{|time|time < t }.each do |t|
          @timers.delete(t).each{|p|p.call}
        end
        update_list(@selectables[:read])
        update_list(@selectables[:write])      
        res = IO.select(@selectables[:read][:io_list], @selectables[:write][:io_list], nil, 0.005)
        if res
          res[0].each do |io|
            if io.respond_to? :notify_readable
              io.notify_readable(self)
            else
              @selectables[:read][:callbacks][io.object_id].call(io) if @selectables[:read][:callbacks][io.object_id] 
            end
          end
          res[1].each do |io|
            if io.respond_to? :notify_writable
              io.notify_writable(self)
            else
              @selectables[:write][:callbacks][io.object_id].call(io) if @selectables[:write][:callbacks][io.object_id]
            end
          end
       end 
      end
    end
    
    # Stops the reactor loop
    # It does not detach any of the attached IO objects, the reactor can be started again
    # and it will keep notifying on the same set of attached IO objects
    # 
    # Stop does not stop the reactor immediately, rather it is stopped at the next cycle,
    # the current cycle continues to completion
    def stop
      @running = false
    end
    
    # Attach an IO object (or an array of them) to the reactor.
    #
    # mode can be either :read or :write
    #
    # If a block is provided it will used as the callback to handle the event,
    # once the event fires the block will be called with the IO object passed
    # as a block parameter.
    #
    # If you supply several IO objects they will all use the same callback block
    #
    # Alternatively, if the IO object implements either notify_readable or notify_writable
    # it will be used instead even if a block was supplied. the reactor itself is sent
    # as a parameter to these methods
    def attach(mode, ios, &callback)
      selectables = @selectables[mode] || raise("mode is not :read or :write")
      (ios = ios.is_a?(Array) ? ios : [ios]).each do |io|
        selectables[:ios][io.object_id] = io 
        selectables[:callbacks][io.object_id] = callback if callback
      end
      selectables[:dirty] = true
    end
    
    # Detach an IO object (on an array of them) from the reactor
    #
    # mode can be either :read or :write
    def detach(mode, ios)
      selectables = @selectables[mode] || raise("mode is not :read or :write")
      (ios = ios.is_a?(Array) ? ios : [ios]).each do |io|
        selectables[:ios].delete(io.object_id)
        selectables[:callbacks].delete(io.object_id)
      end
      selectables[:dirty] = true
    end
    
      
    # Detach all IO objects of a certain mode from the reactor
    #
    # mode can be either :read or :write
    def detach_all(mode)
      raise("mode is not :read or :write") unless [:read, :write].include? mode
      @selectables[mode] = {:ios => {}, :callbacks => {}, :io_list => []}
    end
    
    # Add a block of code that will fire after some time 
    def add_timer(time, &block)
      key = Time.now + time
      if @timers[key]
       @timers[key] << block
      else
       @timers[key] = [block]
      end
    end  
    
    # Add a block of code that will fire periodically after some time passes
    def add_periodical_timer(time, &block)
      ptimer = proc do
        block.call
        add_timer(time){ ptimer.call }
      end    
      add_timer(time){ ptimer.call }
    end
    
    def next_tick &block
      @next_procs << block
    end
    
    # Is the reactor running?
    def running?
      @running
    end
    
    protected
    
    def update_list(selectables)
      selectables[:io_list], selectables[:dirty] = selectables[:ios].values, false if selectables[:dirty]
    end
  end
end 

if __FILE__ == $0
  require 'socket'
  port = (ARGV[0] || 3333).to_i
  puts ">> Reactor library version 1.0 ()"
  puts ">> This is an interactive test"
  puts ">> The console will echo everything you type"
  puts ">> At the same time it will *secretly* listen"
  puts ">> to connections on port #{port} and send"
  puts ">> all that you wrote to whovere asks for it"
  puts ">> Have fun.."  
  buffer = ""
  reactor = Reactor::Base.new
  server = TCPServer.new("0.0.0.0", port)
  reactor.attach(:read, server) do |server|
    conn = server.accept
    conn.write("HTTP/1.1 200 OK\r\nContent-Length:#{buffer.length}\r\nContent-Type:text/plain\r\n\r\n#{buffer}")
    conn.close
  end
  reactor.attach(:read, STDIN) do
    data = gets
    puts data
    buffer << data
  end
  reactor.run
end
