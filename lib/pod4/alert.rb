module Pod4
  

  ##
  # An Alert is an error, warning or note which might be raised in validation
  # in the model. They are, however, designed to follow all the way through the
  # controller to the view; you should use them whenever you want to display a
  # message on the page.
  #
  class Alert

    # Valid values for @type: :error, :warning, :info or :success
    ALERTTYPES = [:error, :warning, :info, :success]

    # The alert type
    attr_reader :type

    # The exception attached to the alert, or nil if there isn't one
    attr_reader :exception

    # The field name associated with the alert, or nil
    attr_accessor :field

    # The alert message
    attr_accessor :message


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
        unless ALERTTYPES.include? type.to_s.to_sym

      @type      = type.to_s.to_sym
      @field     = field ? field.to_sym : nil
      @exception = nil

      if message.kind_of?(Exception)
        @exception = message.dup
        @message   = @exception.message

        # SwingShift validation exceptions hold the field name
        @field ||= @exception.field if @exception.respond_to?(:field)

      else
        @message = message

      end
    end


    ##
    # An array of Alert is automatically sorted into descending order of
    # seriousness
    #
    def <=>(other)
      ALERTTYPES.index(self.type) <=> ALERTTYPES.index(other.type)
    end


    ##
    # Write self to the log
    #
    def log(file='')
      case self.type
        when :error   then Pod4.logger.error(file) { self.message }
        when :warning then Pod4.logger.warn(file)  { self.message }
        else Pod4.logger.info(file) { self.message }
      end

      self
    end


  end
  ##


end
