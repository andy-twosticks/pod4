require "time"
require "thread"

require_relative "interface"
require_relative "connection"
require_relative "errors"


module Pod4


  class ConnectionPool < Connection

    PoolItem = Struct.new(:client, :thread_id)

    class Pool
      def initialize
        @items = []
        @mutex = Mutex.new
      end

      def <<(cl)
        @mutex.synchronize do
          @items << PoolItem.new(cl, Thread.current.object_id)
        end
      end

      def get_current 
        @items.find{|x| x.thread_id == Thread.current.object_id }
      end

      def get_free
        @mutex.synchronize do
          pi = @items.find{|x| x.thread_id.nil? }
          pi.thread_id = Thread.current.object_id if pi
          pi
        end
      end

      def release
        pi = @items.find{|x| x.thread_id == Thread.current.object_id }
        pi.thread_id = nil
      end

      def size 
        @items.size
      end

      def _dump
        @mutex.synchronize do
          @items
        end
      end
    end # of Pool
    
    attr_reader :max_clients, :max_wait

    DEFAULT_MAX_CLIENTS = 10

    ##
    # As Connection, but with some options you can set.
    #
    # * max_clients -- if this many clients are assigned to threads, wait until one is freed.
    # pass nil for no maximum.  Tries to default to something sensible. 
    #
    # * max_wait -- throw a Pod4::PoolTimeout if you wait more than this time in seconds.
    # Pass nil to wait forever. Default is nil, because you would need to handle that timeout.
    #
    def initialize(args)
      super(args)

      @max_clients = args[:max_clients] || DEFAULT_MAX_CLIENTS
      @max_wait    = args[:max_wait]
      @pool        = Pool.new
    end

    ##
    # Return a client for the interface to use.
    #
    # Return the client we gave this thread before. 
    # Failing that, assign a free one from the pool.
    # Failing that, ask the interface to give us a new client.
    #
    # Note: The interface passes itself in case we want to call it back to get a new client; but
    # clients are assigned to a _thread_. Every interface in a given thread gets the same pool
    # item, the same client object.
    #
    def client(interface)
      time = Time.now
      cl   = nil

      # NB: We are constrained to use loop in order for our test to work
      loop do
        if (pi = @pool.get_current)
          cl = pi.client
          break
        end

        if (pi = @pool.get_free)
          cl = pi.client
          break
        end

        if @max_clients && @pool.size >= @max_clients 
          raise Pod4::PoolTimeout if @max_wait && (Time.now - time > @max_wait)
          sleep 1
          next
        end

        cl = interface.new_connection(@data_layer_options)
        @pool << cl
        break
      end # of loop

      cl
    end

    ##
    # De-assign the client for the current thread from that thread.
    #
    # Note: The interface passes itself in case we want to call it back to actually close the
    # client; but clients are assigned to a _thread_.
    #
    def close(interface)
      @pool.release
    end

    ##
    # Dump the internal pool (for test purposes only)
    #
    def _pool
      @pool._dump
    end

  end # of ConnectionPool


end

