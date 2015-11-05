module SwingShift


  ## 
  # Raised in abstract methods when treated as concrete
  #
  class NotImplemented < Error; end


  ##
  # Base error class for Swingshift
  # Note the upgrade to set the existing @cause attribute
  #
  class SwingShiftError < StandardError

    def self.from_error(error)
      raise "trying to raise an error from an error that's not an error" \
        unless error.kind_of? StandardError

      self.new(error.message).cause = error
    end

    def initialize(message=nil); super; end
  end
  ##


  ##
  # Raised if something goes wrong on the database
  #
  class DatabaseError < SwingShiftError; end
  ##


  ##
  # Raised if validation fails (and you wanted an exception...)
  #
  class ValidationError < SwingShiftError
    attr_reader :field

    def self.from_error(error, field=nil)
      super(error).field = field
    end

    def self.from_alert(alert)
      self.new(alert.message, alert.field)
    end

    def initialize(message, field=nil)
      super(message)
      @field = field
    end

  end


end

