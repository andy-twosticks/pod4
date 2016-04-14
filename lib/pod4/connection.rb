module Pod4


  class Connection


    ##
    # Intitialise a Connection by passing it whatever the Interface needs to
    # connect to it.
    #
    # Klass is an interface base type, it's basically there for documentation
    # as much as for validation. 
    #
    def initialize(ifceClass, *args)
      @init_thing = args.size == 1 ? args.first : args
      @ifce_class = ifceClass
      @connection = nil
    end


    ##
    # When an interface wants a connection, it calls connection.connection.
    # If the connection does not have one, it asks the interface for one....
    #
    # bamf: do we want to use a new method `new_connection` on the interface?
    # Or have it call the existing `open` method? 
    #
    # bamf: for SequelInterface, are we passing $db to this class or the
    # connection hash?
    #
    def connection(interface)
      raise Pod4::Something unless interface.kind_of?(@ifce_class)
      @connection ||= interface.new_connection(@init_thing)
    end

  end


end

