require "pod4/connection_pool"


describe Pod4::ConnectionPool do

  let(:ifce_class) do
    Class.new Pod4::Interface do
      def initialize;                  end
      def close_connection;            end
      def new_connection(opts); @conn; end

      def set_conn(c); @conn = c; end
    end
  end


  describe "#new" do
     
    it "accepts some options and stores them as attributes" do
      c = ConnectionPool.new(interface: ifce_class, max_clients: 4, max_wait: 4_000)

      expect( c.max_clients ).to eq 4
      expect( c.max_wait    ).to eq 4_000
    end

    it "falls back to reasonable defaults" do
      c = ConnectionPool.new(interface: ifce_class)

      expect( c.max_clients ).to eq 10
      expect( c.max_wait    ).to eq nil
    end

  end # of #new


  describe "#client" do
     
    context "when there is a client in the pool for this thread" do
      before(:each) do
        @connection = ConnectionPool.new(interface: ifce_class)
        @connection.data_layer_options = "meh"
        @interface = ifce_class.new
        @interface.set_conn "bar"

        # First call to client for a thread should assign a client to it
        @connection.client(@interface)
        expect( @connection._pool.size            ).to eq 1
        expect( @connection._pool.first.thread_id ).to eq Thread.current.object_id
      end
       
      it "returns that client" do
        expect( @interface ).not_to receive(:new_connection)
        expect( @connection.client(@interface) ).to eq "bar"
      end
    end # of when there is a client in the pool for this thread

    context "when there is no client for this thread and a free one in the pool" do
      before(:each) do
        @connection = ConnectionPool.new(interface: ifce_class)
        @connection.data_layer_options = "meh"
        @interface = ifce_class.new
        @interface.set_conn "foo"

        # Call client to assign a client to the thread; then call close to release it. We end up
        # with a client in the pool which is assigned to no thread.
        @connection.client(@interface)
        @connection.close(@interface)
        expect( @connection._pool.size            ).to eq 1
        expect( @connection._pool.first.thread_id ).to be_nil
      end
       
      it "returns the free one" do
        expect( @interface ).not_to receive(:new_connection).and_call_original
        expect( @connection.client(@interface) ).to eq "foo"
      end

      it "assigns the client to this thread id" do
        @connection.client(@interface)
        expect( @connection._pool.size ).to eq 1
        expect( @connection._pool.first.thread_id ).to eq Thread.current.object_id
      end
    end # of when there is no client for this thread and a free one

    context "when max_clients == nil, there is no client for this thread and none free" do
      before(:each) do
        @connection = ConnectionPool.new(interface: ifce_class)
        @connection.data_layer_options = "meh"
        @interface = ifce_class.new
        @interface.set_conn "foo"

        # The simplest case for this scenario is an empty pool
      end

      it "asks the interface to give it a new client and returns that" do
        expect( @interface ).to receive(:new_connection).with("meh").and_call_original
        expect( @connection.client(@interface) ).to eq "foo"
      end

      it "stores the new client from the interface in the pool against the thread" do
        @connection.client(@interface)
        expect( @connection._pool.size ).to eq 1
        expect( @connection._pool.first.thread_id ).to eq Thread.current.object_id
      end
    end # of when max_clients == nil, there is no client for this thread and none free

    context "when max_clients != nil, there is no client for this thread and none free" do

      context "when we're not at the maximum" do
        before(:each) do
          @connection = ConnectionPool.new(interface: ifce_class, max_clients: 1)
          @connection.data_layer_options = "meh"
          @interface = ifce_class.new
          @interface.set_conn "baz"

          #this is an empty pool again
        end

        it "asks the interface to give it a new client and returns that" do
          expect( @interface ).to receive(:new_connection).with("meh").and_call_original
          expect( @connection.client(@interface) ).to eq "baz"
        end

        it "stores the new client from the interface in the pool against the thread" do
          @connection.client(@interface)
          expect( @connection._pool.size ).to eq 1
          expect( @connection._pool.first.thread_id ).to eq Thread.current.object_id
        end
      end

      context "when we reach the maximum" do
        before(:each) do
          @connection = ConnectionPool.new(interface: ifce_class, max_clients: 1)
          @connection.data_layer_options = "meh"
          @interface = ifce_class.new
          @interface.set_conn "boz"

          # assign our 1 client in the pool to a different thread
          @thread = Thread.new do 
            @connection.client(@interface) 
            Thread.stop # pause the thread here until something external restarts it
            sleep 1
            @connection.close(@interface) 
          end
          sleep 0.1 until @thread.stop?

          expect( @connection._pool.size ).to eq 1
          expect( @connection._pool.first.thread_id ).not_to be_nil
          expect( @connection._pool.first.thread_id ).not_to eq Thread.current.object_id
        end

        after(:each) { @thread&.kill }

        it "blocks until a thread is free" do
          # This is hard to test! We can do it but we have to make the horrible assumption that we
          # are using the Ruby `loop` keyword, then stub a loop method to override it.
          expect( @connection ).to receive(:loop).and_yield.and_yield.and_yield

          @connection.client(@interface)
        end

        it "once a client is released it uses that" do
          @thread.run # free pool in 1 sec (we want to be already running #client when it frees)
          expect( @connection.client(@interface) ).to eq "boz" # ...eventually
          expect( @connection._pool.size ).to eq 1
          expect( @connection._pool.first.thread_id ).to eq Thread.current.object_id
        end
      end # of when we reach the maximum

      context "when we reach the maximum, max_wait is set and the time is up" do
        before(:each) do
          @connection = ConnectionPool.new(interface: ifce_class, max_clients: 2, max_wait: 1)
          @connection.data_layer_options = "meh"
          @interface = ifce_class.new
          @interface.set_conn "foo"

          # assign our 2 clients in the pool to a different thread
          @threads = []
          2.times do
            @threads << Thread.new { @connection.client(@interface); Thread.stop }
          end
          sleep 0.1 until @threads.all?{|t| t.stop? }

          expect( @connection._pool.size ).to eq 2
          @threads.each do |t|
            expect( t ).not_to be_nil
            expect( t ).not_to eq Thread.current.object_id
          end
        end

        after(:each) { @threads.each{|t| t.kill} }

        it "raises a PoolTimeout" do
          expect{ @connection.client(@interface) }.to raise_error Pod4::PoolTimeout
        end
      end # of when we reach the maximum, max_wait is set and the time is up

    end # of when max_clients != nil, there is no client for this thread and none free
    
  end # of #client


  describe "#close" do
    before(:each) do
      @connection = ConnectionPool.new(interface: ifce_class)
      @connection.data_layer_options = "meh"
      @interface = ifce_class.new
      @interface.set_conn "brep"

      @connection.client(@interface)
      expect( @connection._pool.size ).to eq 1
      expect( @connection._pool.first.thread_id ).to eq Thread.current.object_id
    end
     
    it "de-assigns the client for this thread from the thread" do
      @connection.close(@interface)
      expect( @connection._pool.size ).to eq 1
      expect( @connection._pool.first.thread_id ).to be_nil
    end

  end # of #close


  describe "(Parallelism)" do

    ##
    # Note that none of these tests _can ever_ fail when running under MRI, because of the GIL.
    #
    # Under jRuby, though, they fail. Probably!  We're relying on >1 thread making the same call
    # simultaneously, with 50 threads all trying to act at the same time. That's not actually
    # _certain_ to happen.  Without the Mutex in ConnectionPool::Pool, these seem to fail MOST of
    # the time.  For me.
    ##

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

