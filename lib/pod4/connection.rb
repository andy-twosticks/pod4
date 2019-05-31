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
    def initialize(args)
      raise ArgumentError, "Connection#new needs a Hash" unless args.is_a? Hash
      raise ArgumentError, "You must pass a Pod4::Interface" \
        unless args[:interface] \
            && args[:interface].is_a?(Class) \
            && args[:interface].ancestors.include?(Interface)

      @interface_class    = args[:interface]
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
    # In the case of a single connection, this is probably not going to get used much. But.
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
        unless f.kind_of?(@interface_class)

    end

  end # of Connection


end

