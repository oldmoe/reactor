$:.unshift File.expand_path(File.dirname(__FILE__))

require 'util'
require 'timer'

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
  #      (Yaki Schloba's Ktools can help here)
  #  - While you can have several reactors in several threads you cannot manipulate
  #    a single reactor from multiple threads.
  # 
  # Rationale
  #
  #  - Reactor libraries are re-implementing every bit of Ruby, 
  #    I would like to see that effort go to Ruby and its standard library 
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
      @next_procs, @timers, @running = [], [], false
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
        run_once
      end
    end
    
    # A single select run, it will fire all expired timers and the callbacks on IO objects
    # but it will return immediately after that. This is useful if you need to create your
    # own loop to interleave the IO event notifications with other operations
    def run_once
      update_list(@selectables[:read])
      update_list(@selectables[:write])            
      if res = IO.select(@selectables[:read][:io_list], @selectables[:write][:io_list], nil, 0.005)
        fire_ios(:read, res[0])
        fire_ios(:write, res[1])
      end 
      fire_procs
      fire_timers
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
    
    # Attach an IO object to the reactor.
    #
    # mode can be either :read or :write
    #
    # A block must be provided and it will be used as the callback to handle the event,
    # once the event fires the block will be called with the IO object and the reactor
    # passed as block parameters.
    #
    # A third argument (which defaults to true) tells the method what to do if the IO
    # object is already attached. If it is set to true (default) then the reactor will
    # append the new call back till the original caller detaches it. If set to false
    # then the reactor will just override the old callback with the new one

    def attach(mode, io, wait_if_attached = true, &callback)
      selectables = @selectables[mode] || raise("mode is not :read or :write")
      raise "you must supply a callback block" if callback.nil?
      if wait_if_attached && selectables[:ios][io.object_id]
        selectables[:callbacks][io.object_id] << callback
      else
        selectables[:ios][io.object_id] = io 
        selectables[:callbacks][io.object_id] = [callback]
        selectables[:dirty] = true
      end
    end
    
    # Detach an IO object from the reactor
    #
    # mode can be either :read or :write
    def detach(mode, io)
      selectables = @selectables[mode] || raise("mode is not :read or :write")
      if selectables[:callbacks][io.object_id].length > 0
        selectables[:callbacks][io.object_id].shift
      else
        selectables[:ios].delete(io.object_id)
        selectables[:callbacks].delete(io.object_id)
        selectables[:dirty] = true
      end
    end
      
    # Detach all IO objects of a certain mode from the reactor
    #
    # mode can be either :read or :write
    def detach_all(mode)
      raise("mode is not :read or :write") unless [:read, :write].include? mode
      @selectables[mode] = {:ios => {}, :callbacks => {}, :io_list => []}
    end
    
    # Ask the reactor if an IO object is attached in some mode
    #
    # mode can be either :read or :write
    def attached?(mode, io)
      @selectables[mode][:ios].include? io
    end

    # Add a block of code that will fire after some time
    def add_timer(time, periodical=false, &block)
      timer = Timer.new(@timers, time, periodical, &block)
    end

    # Add a block of code that will fire periodically after some time passes
    def add_periodical_timer(time, &block)
      add_timer(time, true, &block)
    end
    
    # Register a block to be called at the next reactor tick
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
    
    def fire_procs
      length = @next_procs.length
      length.times { @next_procs.shift.call }
    end
    
    def fire_timers
      return if @timers.length == 0
      t = (Time.now.to_f * 1000).to_i
      while @timers.length > 0 && @timers.first.time_of_fire <= t
        @timers.shift.fire
      end
    end
    
    def fire_ios(mode, ios)
      ios.each {|io|@selectables[mode][:callbacks][io.object_id][0].call(io, self)}
    end
  end
end 

if __FILE__ == $0
  trap('INT') do 
    puts "why did you have to press CTRL+C? why? why?"
    puts "off to the darkness.. again!"
    exit    
  end
  require 'socket'
  port = (ARGV[0] || 3333).to_i
  puts ">> Reactor library version 1.0 ()"
  puts ">> This is an interactive test"
  puts ">> The console will echo everything you type"
  puts ">> At the same time it will *secretly* listen"
  puts ">> to connections on port #{port} and send"
  puts ">> all that you wrote to whoever asks for it"
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
