require_relative 'interface'


module Pod4


  class Connection

    attr_reader   :interface_class
    attr_accessor :data_layer_options

    ##
    # Intitialise a Connection. You must pass a Pod4::Interface class. The connection object will
    # only accept calls from instances of this class.
    #
    # `conn = Pod4::Connection.new(interface: MyInterface)`
    #
    def initialize(args=nil)
      if args
        raise ArgumentError, "Connection#new argument needs to be a Hash" unless args.is_a? Hash

        if args[:interface]
          raise ArgumentError, "You must pass a Pod4::Interface" \
            unless args[:interface] \
                && args[:interface].is_a?(Class) \
                && args[:interface].ancestors.include?(Interface)
        end

        @interface_class = args[:interface]
      end

      @data_layer_options = nil
      @client             = nil
      @options            = nil
    end

    ##
    # When an interface wants a connection, it calls connection.client. If the connection does
    # not have one, it asks the interface for one....
    #
    # Interface is an instance of whatever class you passed to Connection when you initialised
    # it. That is: when an interface wants a connection, it passes `self`.
    #
    def client(interface)
      fail_bad_interfaces(interface)
      @client ||= interface.new_connection(@data_layer_options)
      @client
    end

    ##
    # Close the connection.  
    #
    def close(interface)
      fail_bad_interfaces(interface)
      interface.close_connection 
      @client = nil
      return self
    end

    private

    def fail_bad_interfaces(f)
      raise ArgumentError, "That's not a #@interface_class", caller \
        if @interface_class && !f.kind_of?(@interface_class)

    end

  end # of Connection


end

