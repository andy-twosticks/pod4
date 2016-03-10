module Pod4


  ## 
  # Raised in abstract methods when treated as concrete
  #
  class NotImplemented < Exception
    
    def initialize(msg=nil)
      super(msg || $! && $!.message)
    end

  end


  ##
  # Base error class for Swingshift
  # Note the upgrade to set the existing @cause attribute
  #
  class Pod4Error < StandardError

    def initialize(msg=nil)
      super(msg || $! && $!.message)
    end

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

    def self.from_alert(alert)
      self.new(alert.message, alert.field)
    end

    def initialize(message=nil, field=nil)
      super(message || $! && $!.message)
      @field = field.to_s.to_sym
    end

  end


end

