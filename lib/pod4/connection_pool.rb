require "time"
require "thread"

require_relative "interface"
require_relative "connection"
require_relative "errors"


module Pod4


  class ConnectionPool < Connection

    PoolItem = Struct.new(:client, :thread_id, :stamp)

    class Pool
      def initialize
        @items = []
        @mutex = Mutex.new
      end

      def <<(cl)
        @mutex.synchronize do
          @items << PoolItem.new(cl, Thread.current.object_id, Time.now)
        end
      end

      def get(id)
        @items.find{|x| x.thread_id == id }
      end

      def get_current 
        get(Thread.current.object_id)
      end

      def get_oldest
        @items.sort{|a,b| a.stamp <=> b.stamp}.first
      end

      def get_free
        @mutex.synchronize do
          pi = @items.find{|x| x.thread_id.nil? }
          pi.thread_id = Thread.current.object_id if pi
          pi
        end
      end

      def release(id=nil)
        pi = id.nil? ? get_current : get(id)
        pi.thread_id = nil if pi
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
    # Note that the :interface parameter is optional here.  You probably want one pool for all your
    # models and interfaces, so you should leave it out.
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
    # Failing that, if we've set a timeout, wait for a client to be freed; if we have not, release
    #   the oldest client and use that.
    #
    # Note: 'interface' is the instance of the interface class. It passes itself in case we want to
    # call it back to get a new client or to close a client; but clients are assigned to a
    # _thread_, not an interface. Every interface in a given thread gets the same pool item, the
    # same client object.
    #
    def client(interface)
      time = Time.now
      cl   = nil

      Pod4.logger.debug(__FILE__){ "Pool size: #{@pool.size} Thread: #{Thread.current.object_id}" }

      # NB: We are constrained to use loop in order for our test to work
      loop do
        if (pi = @pool.get_current)
          Pod4.logger.debug(__FILE__){ "get current: #{pi.inspect}" }
          cl = pi.client
          break
        end

        if (pi = @pool.get_free)
          Pod4.logger.debug(__FILE__){ "get free: #{pi.inspect}" }
          cl = pi.client
          break
        end

        if @max_clients && @pool.size >= @max_clients 
          if @max_wait
            raise Pod4::PoolTimeout if @max_wait && (Time.now - time > @max_wait)
            Pod4.logger.warn(__FILE__){ "waiting for a free client..." }
            sleep 1
            next
          else
            Pod4.logger.debug(__FILE__){ "releasing oldest client" }
            oldest = @pool.get_oldest
            interface.close_connection oldest.client
            @pool.release(oldest.thread_id)
            next
          end
        end

        Pod4.logger.debug(__FILE__){ "new connection" }
        cl = interface.new_connection(@data_layer_options)
        @pool << cl
        break
      end # of loop

      Pod4.logger.debug(__FILE__){ "Got client: #{cl.inspect}" }
      cl
    end

    ##
    # De-assign the client for the current thread from that thread.
    #
    # Note: 'interface' is the instance of the interface class.  This is so we can call it
    # and get it to close the client; we don't know how to do that.
    #
    def close(interface)
      current = @pool.get_current
      interface.close_connection current.client
      @pool.release current.thread_id
    end

    ## 
    # Remove the client from the pool but don't try to close it.
    # we provide this for if the Interface finds that a connection is no longer open; TdsInterface
    # uses it.
    #
    def drop(interface)
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

