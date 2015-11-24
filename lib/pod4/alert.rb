module Pod4
  

  ##
  # An Alert is an error, warning or note which might be raised in validation
  # in the model. They are, however, designed to follow all the way through the
  # controller to the view; you should use them whenever you want to display a
  # message on the page.
  #
  class Alert

    ALERTTYPES = [:error, :warning, :info, :success]

    attr_reader :type, :exception

    attr_accessor :field, :message


    ##
    # A new alert must have a type (error warning info or success); there
    # should be a message to display, obviously. Note that you can pass an
    # exception in place of a message, in which case @exception will be set.
    #
    # You may optionally specify the name of the field to be highlighted.
    # Models will give validation alerts a field that corresponds to the model
    # attribute; but this is not enforced here, and your controller will have
    # to sort things out if the model is expecting different field names.
    #
    def initialize(type, field=nil, message)
      raise ArgumentError, "unknown alert type" \
        unless ALERTTYPES.include? type.to_sym

      @type      = type.to_sym
      @field     = field ? field.to_sym : nil
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
