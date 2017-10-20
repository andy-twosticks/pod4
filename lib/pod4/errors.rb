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
  #
  # Also used for any configuration errors where ArgumentError is not appropriate.
  #
  class Pod4Error < StandardError

    def initialize(msg=nil)
      super(msg || $! && $!.message)
      @cos = $!
    end

    unless defined?(cause)
      define_method(:cause) { @cos }
    end

  end
  ##


  ##
  # Raised if something goes wrong on the database
  #
  class DatabaseError < Pod4Error

    def initialize(msg=nil)
      super(msg || $! && $!.message)
    end

  end
  ##


  ##
  # Raised if a Pod4 method runs into problems
  #
  # Note, invalid parameters get a Ruby ArgumentError. This is for, eg, an interface finding that
  # the ID it was given to read does not exist.
  #
  class CantContinue < Pod4Error

    def initialize(msg=nil)
      super(msg || $! && $!.message)
    end

  end
  ##


  ##
  # Raised by an interface if it would like Model to stop and create an Alert, but not actually
  # fall over in any way.
  #
  class WeakError < Pod4Error

    def initialize(msg=nil)
      super(msg || $! && $!.message)
    end

  end
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

