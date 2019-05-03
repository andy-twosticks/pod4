require "octothorpe"

require_relative "metaxing"
require_relative "errors"
require_relative "alert"


module Pod4


  ##
  # The ultimate parent of all models. It has an interface, an id, a status, and alerts. That's
  # pretty much it.
  #
  # This is useful to the user for weirder models -- for example, where the datasource records and
  # the model instances don't map one-to-one.
  #
  # See Pod4::Model for documentation about Models.
  #
  class BasicModel
    extend Metaxing

    # The value of the ID field on the record
    attr_reader :model_id

    # one of Model::STATII
    attr_reader :model_status

    # Valid values for @model_status: :error :warning :okay :deleted or :unknown
    STATII = %i|error warning okay deleted empty|

    class << self

      ##
      # You MUST call this in your model definition to give it an instance of an interface. 
      #
      def set_interface(interface)
        define_class_method(:interface) {interface}
      end

      def interface
        raise NotImplemented, "no call to set_interface in the model"
      end

    end # of class << self

    ##
    # Initialize a model by passing it a unique id value.
    # Override this to set initial values for your column attributes.
    #
    def initialize(id=nil)
      @model_status = :unknown
      @model_id     = id
      @alerts       = []
    end

    ##
    # Syntactic sugar; same as self.class.interface, which returns the interface instance.
    #
    def interface; self.class.interface; end

    ##
    # Return the list of alerts. 
    #
    # We don't use attr_reader for this because it won't protect an array from external changes.
    #
    def alerts; @alerts.dup; end

    ##
    # Clear down the alerts.
    #
    # Note that we set model_status to :okay. Theoretically it might need to be :unknown or :deleted,
    # but if you are calling clear_alerts before a call to `read` or after a call to `delete`, then
    # you have more problems than I can solve.
    #
    def clear_alerts
      @alerts       = []
      @model_status = :okay
    end

    ##
    # Raise a Pod4 exception for the model if any alerts are status :error; otherwise do
    # nothing.
    #
    # Note the alias of or_die for this method, which means that if you have kept to the idiom of
    # CRUD methods returning self, then you can steal a lick from Perl and say:
    #
    #     MyModel.new(14).read.or_die
    #
    def raise_exceptions
      al = @alerts.sort.first
      raise ValidationError.from_alert(al) if al && al.type == :error
      self
    end
    alias :or_die :raise_exceptions

    private

    ##
    # Add a Pod4::Alert to the model instance @alerts attribute
    #
    # Call this from your validation method.
    #
    def add_alert(type, field=nil, message)
      return if @alerts.any? do |a| 
        a.type == type && a.field == field && a.message == message
      end

      lert = Alert.new(type, field, message).log(caller.first.split(':').first)
      @alerts << lert

      st = @alerts.sort.first.type
      @model_status = st if %i|error warning|.include?(st)
    end
    
  end # of BasicModel


end

