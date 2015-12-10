module Pod4


  ## 
  # Raised in abstract methods when treated as concrete
  #
  class NotImplemented < Exception; end


  ##
  # Base error class for Swingshift
  # Note the upgrade to set the existing @cause attribute
  #
  class Pod4Error < StandardError

    attr_accessor :from

    def self.from_error(error)
      raise "trying to raise an error from an error that's not an error" \
        unless error.kind_of? StandardError

      e = self.new( "#{error.class}: #{error.message}" )
      e.from = error.dup
      e
    end

    def initialize(message=nil); super; end
  end
  ##


  ##
  # Raised if something goes wrong on the database
  #
  class DatabaseError < Pod4Error; end
  ##


  ##
  # Raised if validation fails (and you wanted an exception...)
  #
  class ValidationError < Pod4Error
    attr_reader :field

    def self.from_error(error, field=nil)
      super(error).field = field.to_s.to_sym
    end

    def self.from_alert(alert)
      self.new(alert.message, alert.field)
    end

    def initialize(message, field=nil)
      super(message.dup)
      @field = field.to_s.to_sym
    end

  end


end

