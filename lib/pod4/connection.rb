require_relative 'interface'


module Pod4


  class Connection

    attr_reader :interface


    ##
    # Intitialise a Connection by passing it whatever the Interface needs to
    # connect to it.
    #
    def initialize(*args)
      @interface  = nil
      @init_thing = args.count == 1 ? args.first : args
      @connection = nil
    end


    ##
    # Return the value of the init thing, whatever it is
    #
    def init_thing; @init_thing.dup; end


    ##
    # When an interface wants a connection, it calls connection.connection.
    # If the connection does not have one, it asks the interface for one....
    #
    def connection(interface)
      fail_bad_interfaces(interface)
      @interface  ||= interface
      @connection ||= interface.new_connection(@init_thing)
    end


    ##
    # Allows a user to manually set a connection
    #
    # You might want to do this to defer Sequel DB init until after models are
    # required, for example.
    #
    def set_connection(interface, connection)
      fail_bad_interfaces(interface)
      @interface  = interface
      @connection = connection
    end


    ##
    # In the unlikely) event we want to close a connection, we should know how
    # to do it (or how to ask the interface to do it, anyway).
    #
    def close
      @connection = @interface.close_connection if @interface
    end


    private


    def fail_bad_interfaces(f)
      raise ArgumentError, "That\'s not a Pod4::Interface", caller \
        unless f.kind_of?(Interface)

    end

  end


end

