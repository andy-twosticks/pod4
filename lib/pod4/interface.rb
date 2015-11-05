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
    # hashes (or Octothorpes). Exactly what the selection criteria look like
    # will vary from interface to interface. So will the contents of the return
    # OT, although it should include the ID field, or else the model will be
    # much less useful. (Ideally each element of the return array should follow
    # the same format as the return value for read(). )
    #
    # Note that list should ALWAYS return an array; never nil.
    #
    def list(selection=nil)
      raise NotImplemented, "Interface needs to define 'list' method"
    end


    ##
    # Create accepts a record parameter (again, the format of this will vary)
    # representing a record, and creates the record. 
    # Should return the ID for the new record.
    #
    def create(record)
      raise NotImplemented, "Interface needs to define 'create' method"
    end


    ##
    # Read accepts an ID, and returns a Hash / Octothorpe representing the
    # unique record for that ID.
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


  end


end
