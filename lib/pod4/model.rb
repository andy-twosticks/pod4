require 'octothorpe'

require_relative 'errors'
require_relative 'alert'


module Pod4


  ##
  # The ultimate parent of all models.
  #
  # Note that we distinguish between 'models' and 'interfaces':
  #
  # The model represents the data to your application, in the format that makes
  # most sense to your application: that might be the same format that it is
  # stored in on the database, or it might not. The model doesn't care about
  # where the data comes from. Models are all subclasses of Pod4::Model.
  #
  # An interface encapsulates the connection to whatever is providing the data.
  # it might be a wrapper for calls to the Sequel ORM, for example. Or it could
  # be a making a series of calls to a set of Nebulous verbs. It only cares
  # about dealing with the data source, and it is only called by the model.
  #
  # An interface is a seperate class, which is defined for each model. There
  # are parent classes for most of the data sources you will need, but failing
  # that, you can always create one from the ultimate parent, Pod4::Interface.
  #
  # The most basic example model (and interface):
  #
  #     class ExampleModel < Pod4::Model
  #
  #       class ExampleInterface < Pod4::SequelInterface
  #         set_table :example
  #         set_id_fld :id
  #       end
  #
  #       set_interface ExampleInterface.new($db)
  #       attr_columns :one, :two, :three
  #     end
  #
  # In this example we have a model that relies on the Sequel ORM to talk to a
  # table 'example'. The table has a primary key field 'id' and columns which
  # correspond to our three attributes one, two and three.  There is no
  # validation or error control.
  #
  # Here is an example of this model in use:
  #     
  #     # find record 14; raise error otherwise. Update and save.
  #     x = ExampleModel.new(14).read.or_die
  #     x.two = "new value"
  #     x.update
  #
  #     # create a new record from the params hash -- unless validation fails.
  #     y = ExampleModel.new
  #     y.set(params)
  #     y.create unless y.model_status == :error
  #
  class Model

    attr_reader :model_id, :model_status

    STATII = %i|error warning okay deleted empty|


    class << self

      ##
      # You should call this in your model definition to define model 'columns'
      # -- it gives you exactly the functionality of `attr_accessor` but also
      # registers the attribute as one that `to_ot` and `set` will try to help
      # you with.
      #
      def attr_columns(*cols)
        @columns = cols
        attr_accessor *cols
      end


      ##
      # You MUST call this in your model definition to give it an instance of an
      # interface. 
      #
      def set_interface(interface)
        @interface = interface
      end


      def interface
        raise NotImplemented, "no call to set_interface in the model" \
          unless @interface

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
        raise POd4Error, "no ID field defined in interface" \
          unless interface.id_fld

        interface.list(params).map do |ot|
          key = ot[interface.id_fld]
          raise Pod4Error, "ID field missing from record" unless key

          rec = self.new(key)
          rec.set(ot) # seperately, in case model forgot to return self
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
      @model_id     = id
    end


    ##
    # Syntactic sugar; same as self.class.interface, which returns the
    # interface instance.
    #
    def interface; self.class.interface; end


    ##
    # Syntactic sugar; pretty much the same as self.class.columns, which
    # returns the `attr_columns` array.
    #
    def columns; self.class.columns.dup; end


    ##
    # Return the list of alerts. 
    #
    # We don't use attr_reader for this because it won't protect an array from
    # external changes.
    #
    def alerts; @alerts.dup; end


    ##
    # Call this to write a new record to the data source.
    # Note: create needs to set @id. But interface.create should return it, so
    # that's okay.
    #
    def create
      validate
      @model_id = interface.create(to_ot) unless @model_status == :error
      @model_status = :okay if @model_status == :empty
      self
    end


    ##
    # Call this to fetch the data for this instance from the data source
    #
    def read
      set( interface.read(@model_id) )
      @model_status = :okay if @model_status == :empty
      self
    end


    ##
    # Call this to update the data source with the current attribute values
    #
    def update
      raise Pod4Error, "Invalid model status for an update" \
        if [:empty, :deleted].include? @model_status

      validate
      interface.update(@model_id, to_ot) unless @model_status == :error
      self
    end


    ##
    # Call this to delete the record on the data source.
    #
    # Note: does not delete the instance...
    #
    def delete
      raise Pod4Error, "Invalid model status for an update" \
        if [:empty, :deleted].include? @model_status

      validate
      interface.delete(@model_id)
      @model_status = :deleted
      self
    end


    ##
    # Call this to validate the model.
    # Override this to add validation - calling `add_alert` for each problem.
    #
    def validate
      # Hilding pattern. All models should use super, in principal
    end


    ##
    # Set instance values from a Hash or Octothorpe.
    #
    # Override if you need it to set anything not in attr_columns, or to
    # control data types, etc.
    #
    def set(ot)
      raise ArgumentError, 'parameter must be a Hash or Octothorpe' \
        unless ot.kind_of?(Hash) || ot.kind_of?(Octothorpe)
        
      columns.each do |col|
        instance_variable_set("@#{col}".to_sym, ot[col])
      end

      validate

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
    # Raise a SwingShift exception for the model if any alerts are status
    # :error; otherwise do nothing.
    #
    # Note the alias of or_die for this method, which means that if you have
    # kept to the idiom of CRUD methods returning self, then you can steal a
    # lick from Perl and say:
    #     MyModel.new(14).read.or_die
    #
    def raise_exceptions
      al = @alerts.sort.first
      raise ValidationError.from_alert(al) if al && al.type == :error
      self
    end

    alias :or_die :raise_exceptions


    protected

    
    ##
    # Add a Pod4::Alert to the model instance @alerts attribute
    #
    # Call this from your validation method.
    #
    def add_alert(type, field=nil, message)
      @alerts << Alert.new(type, field, message)

      st = @alerts.sort.first.type
      @model_status = st if %i|error warning|.include?(st)
    end


  end
  ##


end

