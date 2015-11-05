module Pod4
  

  ##
  # An Alert is an error, warning or note which a view might want to show on
  # the screen. Alerts span the whole model-view-controller thing, though; they
  # are raised as part of validation on the model and stored in the model.
  # Which is not to say that you can't use them elsewhere.
  #
  class Alert

    attr_reader :type, :field, :message, :exception

    ALERTTYPES = [:error, :warning, :info, :success]


    ##
    # A new alert must have a type (error warning info or success); there
    # should be a message to display, obviously. Note that you can pass an
    # exception in place of a message, in which case @exception will be set.
    #
    # You may optionally specify the name of the field to be highlighted.
    # Models will give validation alerts a field that corresponds to the model
    # attribute; but this is not enforced here.
    #
    def initialize(type, field=nil, message)
      raise "unknown alert type" unless ALERTTYPES.include? type

      @type      = type.to_sym
      @field     = field.to_sym
      @exception = nil

      if message.kind_of?(Exception)
        @exception = message
        @message   = message.message

        # SwingShift validation exceptions hold the field name
        @field ||= message.field if message.respond_to?(:field)

      else
        @message = message

      end
    end


    ##
    # Sort alerts in descending order of seriousness
    #
    def <=>(other)
      ALERTTYPES.index(self.type) <=> ALERTTYPES.index(other.type)
    end


    ## 
    # Return the Bootstrap notification class for this error 
    #
    def bootstrap_class
      @type == :error ? 'alert-danger' : "alert-#@type"
    end


  end
  ##


end
