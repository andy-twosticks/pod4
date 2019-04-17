require "pod4/connection_pool"


##
# These tests cover how connection pool handles being called by simultaneous threads.  Note that
# none of these tests _can ever_ fail when running under MRI, because of the GIL.
#
# Under jRuby, though, they can fail. Probably!  We're relying on >1 thread making the same call
# simultaneously, with 50 threads all trying to act at the same time. That's not actually _certain_
# to happen.  Without the Mutex in ConnectionPool::Pool, these seem to fail MOST of the time.  For
# me.
#
# These tests are in a seperate spec file because they screw up the test suite.  One of two things
# happens: 
#
# * A timeout waiting for threads to be "done" or be killed
# * A Stomp timeout error(!?)
#
# You can duplicate this by running these three tests, in this order:
#
# 1. This one
# 2. NebulousInterface
# 3. SequelInterface (pg)
#
# (It passes when you run it on its own.)
#
# My working theory is that we just run out of threads, somehow? It might be something to do with
# this jRuby bug: https://github.com/jruby/jruby/issues/5476
#
# For the time being I've renamed this test file `_spoc` instead of `_spec` so that it's not part
# of the test suite. 
#
describe Pod4::ConnectionPool do

  let(:ifce_class) do
    Class.new Pod4::Interface do
      def initialize;                  end
      def close_connection;            end
      def new_connection(opts); @conn; end

      def set_conn(c); @conn = c; end
    end
  end


  describe "(Parallelism)" do

    before(:each) do
      # If a thread suffers an exception, that's probably because of a race condition somewhere.
      # eg: without the Mutex on ConnectionPool::Pool, nils get assigned to the pool somehow.
      Thread.abort_on_exception = true

      @connection = ConnectionPool.new(interface: ifce_class, max_clients: 55)
      @connection.data_layer_options = "meh"
      @interface = ifce_class.new
      @interface.set_conn "floom"

      # Set up 50 threads to call things at the same time.
      # Note -- for some unknown reason `Thread.stop` is better than `sleep` for making the 
      # unsecured code fail.
      @threads = []
      1.upto(50) do |idx|
        @threads << Thread.new do 
          # Set things up and wait
          Thread.current[:idx] = idx # might be useful for debugging
          Thread.stop

          # wait for the given sync time;  call #client; signal done; then wait
          sleep 0.1 until Time.now >= Thread.current[:time]
          @connection.client(@interface)
          Thread.current[:done] = true
          Thread.stop 

          # call #close; signal done; then wait
          @connection.close(@interface)
          Thread.current[:done] = true
          Thread.stop
        end
      end

    end

    after(:each) { @threads.each{|t| t.kill} }
     
    it "assigns new items to the pool from multiple threads successfully" do
      test_start = Time.now

      # tell all the threads to connect
      at = Time.now + 2
      @threads.each{|t| t[:time] = at }
      @threads.each{|t| t.run         }
      sleep 0.1 until @threads.all?{|t| t[:done] } || Time.now >= test_start + 10
      expect( @threads.all?{|t| t[:done] } ).to eq true

      expect( @connection._pool.size                               ).to eq 50
      expect( @connection._pool.select{|x| x.thread_id.nil? }.size ).to eq 0
    end

    #
    # Note that we don't have to test the safety of the operation of retrieving the client for an
    # already assigned thread, or for freeing that client for use by other threads -- since only
    # one thread can ever access that pool item...
    #

    it "reassigns items to new threads from multiple threads successfully" do
      test_start = Time.now

      # tell all the threads to connect
      @threads.each{|t| t[:time] = Time.now }
      @threads.each{|t| t.run               }
      sleep 0.1 until @threads.all?{|t| t[:done] } || Time.now >= test_start + 10
      expect( @threads.all?{|t| t[:done] } ).to eq true

      # Release all the connections
      @threads.each{|t| t[:done] = false }
      @threads.each{|t| t.run            }
      sleep 0.1 until @threads.all?{|t| t[:done] } || Time.now >= test_start + 10
      expect( @threads.all?{|t| t[:done] } ).to eq true

      # Make some new threads. These should reuse connections from the pool.
      newthreads = []
      1.upto(48) do |idx|
        newthreads << Thread.new do
          Thread.current[:idx] = "n#{idx}" # might be useful for debugging
          Thread.stop
          # sleep

          sleep 0.1 until Time.now >= Thread.current[:time]
          @connection.client(@interface)
          Thread.current[:done] = true
          Thread.stop
        end
      end

      at = Time.now + 2
      newthreads.each{|t| t[:time] = at }
      newthreads.each{|t| t.run         }
      sleep 0.1 until newthreads.all?{|t| t[:done] } || Time.now >= test_start + 10
      expect( newthreads.all?{|t| t[:done] } ).to eq true

      expect( @connection._pool.size                               ).to eq 50
      expect( @connection._pool.select{|x| x.thread_id.nil? }.size ).to eq 50 - 48

      # tidy up
      newthreads.each{|t| t.kill }
    end
    
  end # of (Parallelism)
  
  
end

