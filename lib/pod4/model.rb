require 'octothorpe'

require_relative 'basic_model'
require_relative 'errors'
require_relative 'alert'


module Pod4


  ##
  # The parent of all CRUDL models.
  #
  # Models & Interfaces
  # -------------------
  #
  # Note that we distinguish between 'models' and 'interfaces':
  #
  # The model represents the data to your application, in the format that makes most sense to your
  # application: that might be the same format that it is stored in on the database, or it might
  # not. The model doesn't care about where the data comes from. Models are all subclasses of
  # Pod4::Model.
  #
  # An interface encapsulates the connection to whatever is providing the data. It might be a
  # wrapper for calls to the Sequel ORM, for example. Or it could be a making a series of calls to
  # a set of Nebulous verbs. It only cares about dealing with the data source, and it is only
  # called by the model.
  #
  # An interface is a seperate class, which is defined for each model. There are parent classes for
  # most of the data sources you will need, but failing that, you can always create one from the
  # ultimate parent, Pod4::Interface.
  #
  # Simple Example
  # ---------------
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
  # In this example we have a model that relies on the Sequel ORM to talk to a table 'example'. The
  # table has a primary key field 'id' and columns which correspond to our three attributes one,
  # two and three.  There is no validation or error control.
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
  # Overriding Column Representation
  # --------------------------------
  #
  # If you want to represent information differently on the model than it is stored on the data
  # source, there are four methods you potentially need to know about and override:
  #
  # * set -- used by you to set model column values
  # * to_ot -- used by you to get model column values
  # * map_to_model -- used by the model to set column values from the interface
  # * map_to_interface -- used by the model to set interface values 
  #
  # See the methods themselves for more detail.
  #
  class Model < Pod4::BasicModel

    class << self

      ##
      # You should call this in your model definition to define model 'columns' -- it gives you
      # exactly the functionality of `attr_accessor` but also registers the attribute as one that
      # `to_ot`, `map_to_model` and `map_to_interface` will try to help you with.
      #
      def attr_columns(*cols)
        c = columns.dup
        c += cols
        define_class_method(:columns) {c}
        attr_accessor *cols
      end

      ##
      # Returns the list of columns from attr_columns
      #
      def columns 
        []
      end

      ##
      # Call this to return an array of record information.
      #
      # What you actually get depends on the interface, but it must include a recognisable record
      # ID in each array element.  
      #
      # For the purposes of Model we assume that we can make an instance out of each array element,
      # and we return an array of instances of the model. Override this method if that is not true
      # for your Interface.
      #
      # Note that list should ALWAYS return an array, and array elements should always respond to
      # :id -- otherwise we raise a Pod4Error.
      #
      # Note also that while list returns an array of model objects, `read` has _not_ been run
      # against each object. The data is there, but @model_status == :empty, and validation has not
      # been run.  This is partly for the sake of efficiency, partly to help avoid recursive loops
      # in validation.
      #
      def list(params=nil)
        fail_no_id_fld unless interface.id_fld

        interface.list(params).map do |ot|
          key = ot[interface.id_fld]; fail_no_id unless key

          rec = self.new(key)
          rec.map_to_model(ot) # seperately, in case model forgot to return self
          rec 
        end
      end

      def test_for_octo(param)
        raise( ArgumentError, 'Parameter must be a Hash or Octothorpe', caller ) \
          unless param.kind_of?(Hash) || param.kind_of?(Octothorpe)

      end

      def test_for_invalid_status(action, status)
        raise( Pod4Error, "Invalid model status for an action of #{action}", caller ) \
          if [:empty, :deleted].include? status

      end

      def fail_no_id_fld
        raise Pod4Error, "No ID field defined in interface", caller
      end

      def fail_no_id
        raise Pod4Error, "ID field missing from record", caller
      end

    end # of class << self

    ##
    # Syntactic sugar; pretty much the same as self.class.columns, which returns the `attr_columns`
    # array.
    #
    def columns; self.class.columns.dup; end

    ##
    # Call this to write a new record to the data source.
    #
    # Note: create needs to set @id. But interface.create should return it, so that's okay.
    #
    def create
      run_validation(:create)
      @model_id = interface.create(map_to_interface) unless @model_status == :error

      @model_status = :okay if @model_status == :empty
      self
    rescue Pod4::WeakError
      add_alert(:error, $!)
      self
    end

    ##
    # Call this to fetch the data for this instance from the data source
    #
    def read
      r = interface.read(@model_id)

      if r.empty?
        add_alert(:error, "Record ID '#@model_id' not found on the data source")
      else
        map_to_model(r)
        run_validation(:read)
        @model_status = :okay if @model_status == :empty
      end

      self
    rescue Pod4::WeakError
      add_alert(:error, $!)
      self
    end

    ##
    # Call this to update the data source with the current attribute values
    #
    def update
      Model.test_for_invalid_status(:update, @model_status)

      clear_alerts; run_validation(:update)
      interface.update(@model_id, map_to_interface) unless @model_status == :error

      self
    rescue Pod4::WeakError
      add_alert(:error, $!)
      self
    end

    ##
    # Call this to delete the record on the data source.
    #
    # Note: does not delete the instance...
    #
    def delete
      Model.test_for_invalid_status(:delete, @model_status)
      clear_alerts; run_validation(:delete)

      unless @model_status == :error
        interface.delete(@model_id) 
        @model_status = :deleted
      end
      self
    rescue Pod4::WeakError
      add_alert(:error, $!)
      self
    end

    ##
    # Call this to validate the model.
    #
    # Override this to add validation - calling `add_alert` for each problem.
    #
    # Note that you can only validate what is actually stored on the model. If you want to check
    # the data being passed to the model in `set`, you need to override that routine.
    #
    # You may optionally catch the vmode parameter, which is one of :create,
    # :read, :update, :delete, to have different validation under these circumstances; or you may
    # safely ignore it and override `create`, `read`, `update` or `delete` as you wish.
    #
    def validate(vmode=nil)
      # Holding pattern. All models should use super, in principal
    end

    ##
    # Set instance values on the model from a Hash or Octothorpe.
    #
    # This is what your code calls when it wants to update the model. Override it if you need it to
    # set anything not in attr_columns, or to control data types, etc.
    #
    # You might want to put validation here, too, if what you are validating is something that
    # isn't actually stored on the model. You can call add_alert from here just fine.
    #
    # See also: `to_ot`, `map_to_model`, `map_to_interface`
    #
    def set(ot)
      merge(ot)
      self
    end

    ##
    # Return an Octothorpe of all the attr_columns attributes.
    #
    # Override if you want to return any extra data. (You will need to create a new Octothorpe.) 
    #
    # See also: `set`, `map_to_model', 'map_to_interface'
    #
    def to_ot
      Octothorpe.new(to_h)
    end

    ##
    # Used by the interface to set the column values on the model.
    #
    # Don't use this to set model attributes from your code; use `set`, instead.
    #
    # By default this does exactly the same as `set`. Override it if you want the model to
    # represent data differently than the data source does -- but then you will have to override
    # `map_to_interface`, too, to convert the data back.
    #
    # See also: `to_ot`, `map_to_model'
    #
    def map_to_model(ot)
      merge(ot)
      self
    end

    ##
    # used by the model to get an OT of column values for the interface. 
    #
    # Don't use this to get model values in your code; use `to_ot`, instead.# This is called by
    # model.create and model.update when it needs to write to the data source.
    #
    # By default this behaves exactly the same as to_ot. Override it if you want the model to
    # represent data differently than the data source -- in which case you also need to override
    # `map_to_model`.
    #
    # Bear in mind that any attribute could be nil, and likely will be when `map_to_interface` is
    # called from the create method.
    #
    # See also: `to_ot`, `set`.
    #
    def map_to_interface
      Octothorpe.new(to_h)
    end

    private

    ##
    # Output a hash of the columns
    #
    def to_h
      columns.each_with_object({}) do |col, hash|
        hash[col] = instance_variable_get("@#{col}".to_sym)
      end
    end

    ##
    # Merge an OT with our columns
    #
    def merge(ot)
      Model.test_for_octo(ot)

      columns.each do |col|
        instance_variable_set("@#{col}".to_sym, ot[col]) if ot.has_key?(col)
      end
    end

    ##
    # Call the validate method on the model.  Allow the user to override the method with or without
    # the vmode paramter, as they choose.
    #
    def run_validation(vmode)
      method(:validate).arity == 0 ? validate : validate(vmode)
      self
    end

  end # of Model


end

