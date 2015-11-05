require 'octothorpe'

require 'core/lib/errors'
require 'core/lib/alert'


module SwingShift


  ##
  # The ultimate parent of all SwingShift models.
  #
  # Note that we distinguish between 'models' and 'interfaces'. An interface
  # encapsulates connection to whatever is providing the data, for example, a
  # database.  A model *is* the data, as far as SwingShift is concerned, and
  # might not look anything like the database record or records that the
  # interface provides to fill it. 
  #
  # An interface is a seperate class, a child of SwingShift::Interface. Each
  # model has one interface. 
  #
  # The most basic example model:
  #
  #     class ExampleModel < SwingShift::Model
  #
  #       class ExampleInterface < SwingShift::SequelInterface
  #         set_table :example
  #         set_id_fld :id
  #       end
  #
  #       set_interface SwingShift::SequelInterface(DB)
  #       attr_columns :one, :two, :three
  #     end
  #
  # In this example we have a model that relies on the Sequel ORM to talk to a
  # table 'example'. The table has a primary key field 'id' and columns which
  # correspond to our three attributes one, two and three.  There is no
  # validation or error control.
  #
  class Model

    attr_reader :id, :alerts, :model_status

    STATII = %i|error warning okay empty|


    class << self

      def attr_columns(*cols)
        @columns = cols
        attr_accessor *cols
      end


      def set_interface(interface)
        @interface = interface
      end


      def interface
        raise "no call to set_interface in the model" unless @interface
        @interface
      end


      def columns 
        @columns || []
      end


      ##
      # Call this to return an array of record information.
      #
      # What you actually get depends on the interface, but it must include a
      # recognisable record ID in each array element.  
      #
      # For the purposes of Model we assume that we can make an instance out of
      # each array element, and we return an array of instances of the model.
      # Override this method if that is not true for your Interface.
      #
      # Note that list should ALWAYS return an array.
      #
      def list(params=nil)

        interface.list(params).map do |rec|
          key = rec[interface.id_fld]
          raise "ID field missing from record" unless key

          rec = self.new(key)
          rec.set(rec) # do this seperately in case model forgot to return self
          rec 
        end

      end

    end
    ##


    ##
    # Initialize a model by passing it a unique id value.
    # Override this to set initial values for your column attributes.
    #
    def initialize(id=nil)
      @model_status = :empty
      @alerts       = []
      @id           = id
    end


    ##
    # Syntactic sugar; same as self.class.interface
    #
    def interface; self.class.interface; end


    ##
    # Syntactic sugar; same as self.class.columns
    #
    def columns; self.class.columns; end


    ##
    # Call this to write a new record to the data source.
    # Note: create needs to set @id. But interface.create should return it, so
    # that's okay.
    #
    def create
      validate
      @id = interface.create( to_ot )
      self
    end


    ##
    # Call this to fetch the data for this instance from the data source
    #
    def read
      set( interface.read(@id) )
      validate
      self
    end


    ##
    # Call this to update the data source with the current attribute values
    #
    def update
      validate
      interface.update(@id, to_ot)
      self
    end


    ##
    # Call this to delete the record on the data source.
    #
    # Note: does not delete the instance...
    #
    def delete
      validate
      interface.delete(@id)
      self
    end


    ##
    # Call this to validate the model.
    # Override this to add validation - calling `add_alert` for each problem.
    #
    def validate
      super
    end


    ##
    # Set instance values from a Hash or Octothorpe.
    #
    # Override if you need it to set anything not in attr_columns, or to
    # control data types, etc.
    #
    def set(ot)
      columns.each do |col|
        instance_variable_set("@#{col}".to_sym, ot[col])
      end

      self
    end


    ##
    # Return an Octothorpe of all the attr_columns attributes.
    #
    # Override if you want to return any extra data. (You will need to create a
    # new Octothorpe.)
    #
    def to_ot
      hash = columns.each_with_object({}) do |col, hash|
        hash[col] = instance_variable_get("@#{col}".to_sym)
      end

      Octothorpe.new(hash)
    end


    ##
    # Throw a SwingShift exception for the model if any alerts are status
    # :error; otherwise do nothing.
    #
    # Note the alias of or_die for this method, which means that if you have
    # kept to the idiom of CRUD methods returning self, then you can steal a
    # lick from Perl and say:
    #     MyModel.new(14).read.or_die
    #
    def throw_exceptions
      al = @alerts.sort.first
      raise ValidationError.from_alert(al) if al.type == :error
      self
    end

    alias :or_die :throw_exceptions


    protected

    
    ##
    # Add an alert to the model instance @alerts attribute
    #
    # Call this from your validation method.
    #
    def add_alert(type, field=nil, message)
      @alerts << SwingShift::Alert.new(type, field, message)

      st = @alerts.sort.first.type
      @model_status = st if %i|error warning|.include?(st)
    end


  end
  ##


end

