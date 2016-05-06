require_relative 'interface'


module Pod4


  class Connection

    attr_reader :interface


    ##
    # Intitialise a Connection by passing it whatever the Interface needs to
    # connect to it.
    #
    # Klass is an interface base type, it's basically there for documentation
    # as much as for validation. 
    #
    def initialize(interface, *args)
      raise ArgumentError, "#{interface} is not an Interface" \
        unless interface.kind_of? Interface

      @interface  = interface
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
    # bamf: for SequelInterface, are we passing $db to this class or the
    # connection hash?
    #
    def connection
      @connection ||= @interface.new_connection(@init_thing)
    end


    ##
    # Allows a user to manually set a connection
    #
    # You might want to do this to defer Sequel DB init until after models are
    # required, for example.
    #
    def set_connection(connection)
      @connection = connection
    end


    ##
    # In the unlikely) event we want to close a connection, we should know how
    # to do it (or how to ask the interface to do it, anyway).
    #
    def close
      @connection = @interface.close_connection
    end

  end


end

