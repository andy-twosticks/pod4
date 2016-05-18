require_relative 'errors'


module Pod4


  ##
  # Abstract class, The parent of all interfaces.
  #
  # An interface encapsulates whatever method we are using up connect to the
  # data. Its state is therefore that of the connection, not the DB table or
  # whatever entity that the data source uses to group data. It raises only
  # SwingShift errors (wrapping the error it gets inside a SwingShift error).
  #
  # We would expect a child of Interface for each data access type
  # (sequelInterface, NebulousInterface, etc). These children *will not change*
  # the signatures of the methods below.
  #
  # The methods below are the required ones. Interfaces will likely implement
  # other, interface-specific, ways of accessing data.
  #
  # In Normal use, the interface classes will in turn be subclassed as inner
  # classes within each model, in order to customise them for the specific
  # entity that they are drawing data from. 
  #
  # Note that your Interface subclass probably returns an Octothorpe rather
  # than a Hash, q.v..  (But you should be able to treat the former as if it
  # were the latter in most cases.)
  #
  class Interface

    ACTIONS = [ :list, :create, :read, :update, :delete ]

    # A field name in the data source, the name of the unique ID field.
    attr_reader :id_fld


    ##
    # Individual implementations are likely to have very different initialize
    # methods, which will accept whatever SwingShift object is needed to
    # contact the data store, eg. the Sequel DB object. 
    #
    def initialize
      raise NotImplemented, "Interface needs to define an 'initialize' method"
    end


    ##
    # List accepts a parameter as selection criteria, and returns an array of
    # Octothorpes. Exactly what the selection criteria look like will vary from
    # interface to interface. So will the contents of the return OT, although
    # it must include the ID field. (Ideally each element of the return array
    # should follow the same format as the return value for read(). )
    #
    # Note that list should ALWAYS return an array; never nil.
    #
    def list(selection=nil)
      raise NotImplemented, "Interface needs to define 'list' method"
    end


    ##
    # Create accepts a record parameter (Hash or OT, but again, the format of
    # this will vary) representing a record, and creates the record.  Should
    # return the ID for the new record.
    #
    def create(record)
      raise NotImplemented, "Interface needs to define 'create' method"
    end


    ##
    # Read accepts an ID, and returns an Octothorpe representing the unique
    # record for that ID. If there is no record matching the ID then it returns
    # an empty Octothorpe.
    #
    def read(id)
      raise NotImplemented, "Interface needs to define 'read' method"
    end


    ##
    # Update accepts an ID and a record parameter. It updates the record on the
    # data source that matches the ID using the record parameter.  It returns
    # self.
    #
    def update(id, record)
      raise NotImplemented, "Interface needs to define 'update' method"
    end


    ##
    # delete removes the record with the given ID. returns self.
    #
    def delete(id)
      raise NotImplemented, "Interface needs to define 'delete' method"
    end


    ##
    # Called by a Connection object to start a database connection
    #
    def new_connection(args)
      raise NotImplemented, "Interface needs to define 'new_connection' method"
    end


    ##
    # Called by a Connection Object to close the connection.
    #
    def close_connection
      raise NotImplemented, "Interface needs to define 'close_connection' method"
    end


  end


end
