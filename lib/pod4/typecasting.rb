#require 'BigDecimal'
require 'time'
require 'pod4/errors'
require 'pod4/metaxing'


module Pod4


  ##
  # A mixin to give you some more options to control how Pod4 deals with data types.
  #
  # Example
  # -------
  #
  #     class Foo < Pod4::Model
  #       include Pod4::TypeCasting
  #    
  #       class Interface < Pod4::SomeInterface
  #         # blah blah blah
  #       end
  #       set_interface Interface.new($stuff)
  #    
  #       attr_columns :name, :issue, :created, :due, :last_update, :completed, :thing
  #    
  #       # Now the meat
  #       force_encoding Encoding::UTF-8
  #       typecast :issue,         as: Integer, strict: true
  #       typecast :created, :due, as: Date
  #       typecast :last_update,   as: Time
  #       typecast :completed,     as: BigDecimal, ot_as: Float
  #       typecast :thing,         use: mymethod
  #     end
  #
  # So this adds two commands to the model DSL: force_encoding, and typecast. Both are optional.
  #
  # Force Encoding
  # --------------
  #
  # Pass this a Ruby encoding, and it will call force the encoding of each incoming value from the
  # database to match. It is to work around problems with some data sources like MSSQL, which may
  # deal with encoding poorly.
  #
  # Typecasting
  # -----------
  #
  # This has the syntax: `typecast <attr> [,...], <options>`.
  #
  # Options are `as:`, `ot_as:`, `strict:` and `use:`. You must specify either `as:` or `use:`.
  #
  # Valid types are BigDecimal, Float, Integer, Date, Time, and :boolean. 
  #
  # Changes to Behaviour of Model
  # -----------------------------
  #
  # General: Any attributes named using `typecast` are set `attr_reader` if they are not already
  # so. 
  #
  # `map_to_model`: incoming data from the data source is coerced to the given encoding if
  # `force_encoding` has been used. Typecast attributes are cast as per their settings, or if they
  # cannot be cast, are left alone. (Unless you have specified strict: true, in which case they are
  # set to nil.)
  #
  # `set()`: typecast attributes are cast as per their settings, or if they cannot be cast, are left
  # alone. (Unless you have specified `strict: true`, in which case they are set to nil.)
  #
  # `to_ot()`: any typecast attributes with `ot_as` are cast that way in the outgoing OT, and set
  # guard that way too (see Octothorpe#guard) to give a reasonable default value instead of nil.
  #
  # `map_to_interface()`: typecast attributes are cast as per their settings, or if they cannot be
  # cast, are set to nil.
  #
  # Note: Typecasting does not prevent you from setting any value you please on a model attibute
  # @foo by using `model.foo = value`.
  #
  # Additional methods
  # ------------------
  #
  # The following are provided:
  #
  # * `typecast?(:columnname, value)` returns true if the value can be cast; value defaults to the
  #   column value if not given.
  # 
  # * `typecast(type, value, options)` returns a typecast value, or either the original value, or
  # nil if options[:strict] is true.
  # 
  # * `guard(octothorpe)` sets guard conditions on the given octothorpe, based on the attributes
  #   typecast knows about. If the value was nil, it will be a reasonable default for the type
  #   instead.
  #
  # Custom Typecasting Methods
  # --------------------------
  #
  # By specifying `use: my_method` you are telling Pod4 that you have a method that will return the
  # typecast value for the type.  This method will be called as `my_method(value, options)`,
  # where value is the value to be typecast, and options is the hash of options you specified for
  # that column.  Pod4 will set the column to whatever your method returns.
  #
  # The options hash will have an additional key :mode in case you need to cast differently in
  # different circumstances.  Mode will be one of :set, :map_to_interface, :map_to_model, or
  # :typecast? (if you call `typecast?` yourself).
  #
  # What you don't get
  # ------------------
  #
  # None of this has any direct effect on validation, although of course we do provide methods such
  # as `typecast?()` to specifically help you with validation.
  #
  # Naming an attribute using `typecast` does not automatically make it a Pod4 column; you need to
  # use `attr_column`, just as in plain Pod4. Furthermore, *only* Pod4 columns can be named in the
  # typecast command, although you can use the `typecast` instance method, etc., to help you roll
  # your own typecasting for non-column attributes.
  #
  # Loss of information.  If your column is typecast to Integer, then setting it to 12.34 will not
  # round it to 12. Likewise, I know that Time.to_date is a thing, but we don't support it.
  #
  # Protection from nil, except when using `ot_as:`. A column is always allowed to be nil,
  # regardless of how it is typecast. (On the contrary: by forcing strict columns to nil if they
  # fail typecasting, we help you validate.)
  #
  # It's theoretically possible that you could typecast a column into something that the
  # interface cannot cast back onto the database.  We don't cover you in that case. If it happens,
  # you will have to deal with it yourself in `map_to_interface`.
  #
  module TypeCasting

    TYPES = [ Date, Time, Integer, Float, BigDecimal, :boolean ]

    ##
    # A little bit of magic, for which I apologise. 
    #
    # When you include this module it actually adds the methods in ClassMethods to the class as if
    # you had called `extend TypeCasting:ClassMethds` *AND* adds the methods in InstanceMethods as
    # if you had written `prepend TypeCasting::InstanceMethods`.  
    #
    # In my defence: I didn't want to have to make you remember to do that...
    #
    def self.included(base)
      base.extend  ClassMethods
      base.send(:prepend, InstanceMethods)
    end


    module ClassMethods
      include Metaxing

      def force_encoding(enc)
        raise Pod4Error, "Bad encoding" unless enc.kind_of? Encoding
        define_class_method(:encoding){enc}
      end

      def encoding; nil; end

      def typecast(*args)
        options = args.pop
        raise Pod4Error, "Bad Type" \
          unless options.keys.include?(:use) || TYPES.include?(options[:as])

        raise Pod4Error, "Bad Typecasting" unless options.is_a?(Hash) \
                                               && options.keys.any?{|o| %i|as use|.include? o} \
                                               && args.size >= 1

        # Modify self.typecasts to look like: {foo: {as: Date}, bar: {as: Time, strict: true}, ...}
        c = typecasts.dup
        args.each do |f| 
          raise Pod4Error, "Unknown column '#{f}'" unless columns.include?(f)
          c[f] = options
        end

        define_class_method(:typecasts) {c}
      end

      def typecasts; {}; end

    end # of ClassMethods


    module InstanceMethods

      def map_to_model(ot)
        enc = self.class.encoding
        
        ot.each_value do |v|
          v.force_encoding(enc) if v.kind_of?(String) && enc
        end

        hash = typecast_ot(ot, mode: :map_to_model)
        super(ot.merge hash)
      end

      def set(ot)
        hash = typecast_ot(ot, mode: :set)
        super(ot.merge hash)
      end

      def map_to_interface
        ot   = super
        hash = typecast_ot(ot, strict: true, mode: :map_to_interface)
        ot.merge hash
      end

      def to_ot
        ot  = super
        ot2 = ot.merge typecast_ot_to_ot(ot)

        self.class.typecasts.each do |fld, tc|
          set_guard(ot2, fld, tc[:ot_as]) if tc[:ot_as]
        end

        ot2
      end

      ##
      # Return thing cast to type. If opt[:strict] is true, then return nil if thing cannot be
      # cast to type; otherwise return thing unchanged.
      #
      def typecast(type, thing, opt={})
        # Nothing to do
        return thing if type.is_a?(Class) && thing.is_a?(type)

        # Nothing wrong with nil for our purposes; it's always allowed
        return thing if thing.nil?

        # For all current cases, attempting to typecast a blank string should return nil
        return nil if thing =~ /\A\s*\Z/ 

        # The order we try these in matters
        return tc_bigdecimal(thing) if type == BigDecimal 
        return tc_float(thing)      if type == Float      
        return tc_integer(thing)    if type == Integer    
        return tc_date(thing)       if type == Date       
        return tc_time(thing)       if type == Time       
        return tc_boolean(thing)    if type == :boolean   

        fail Pod4Error, "Bad type passed to typecast()"
      rescue ArgumentError
        return (opt[:strict] ? nil : thing)
      end

      ## 
      # Return true if the attribute can be cast to the given value.
      # You must name an attribute you specified in a typecast declaration, or you will get an
      # exception. 
      # You may pass a value to test, or failing that, we take the current value of the attribute.
      #
      def typecast?(attr, val=nil)
        fail Pod4Error, "Unknown column passed to typecast?()" \
          unless (tc = self.class.typecasts[attr])

        val = instance_variable_get("@#{attr}".to_sym) if val.nil?
        !typecast_one(val, tc.merge(strict: true, mode: :typecast?)).nil?
      end

      ## 
      # set Octothorpe Guards for everything in the given OT, based on the typecast settings.
      #
      def guard(ot)
        self.class.typecasts.each do |fld, tc|
          type = tc[:ot_as] || tc[:as]
          set_guard(ot, fld, type) if type
        end
      end

      private

      ## 
      # Return a hash of changes for an OT based on our settings
      #
      def typecast_ot(ot, opts={})
        hash = {}
        ot.each do |k,v|
          tc = self.class.typecasts[k]
          hash[k] = typecast_one(v, tc.merge(opts)) if tc
        end
        hash
      end

      ##
      # As typecast_ot, but this is a specific helper for to_ot
      #
      def typecast_ot_to_ot(ot)
        hash = {}
        ot.each do |k,v|
          tc = self.class.typecasts[k]
          hash[k] = (tc && tc[:ot_as]) ? typecast(tc[:ot_as], v) : v
        end
        hash
      end

      ## 
      # Helper for typecast_ot: cast one attribute
      #
      def typecast_one(val, tc)
        if tc[:use]
          self.__send__(tc[:use], val, tc)
        else
          typecast(tc[:as], val, tc) 
        end
      end

      ##
      # Set the guard clause for one attribute
      # Note that Time.new returns now, and Date.new returns some date in antiquity. We don't
      # consider those helpful, so we give you 1900-1-1 in both cases
      #
      def set_guard(ot, fld, tc)
        case tc.to_s
          when "BigDecimal" then ot.guard(fld) { BigDecimal("0")      }
          when "Float"      then ot.guard(fld) { Float(0)             }
          when "Integer"    then ot.guard(fld) { Integer(0)           }
          when "Date"       then ot.guard(fld) { Date.new(1900, 1, 1) }
          when "Time"       then ot.guard(fld) { Time.new(1900, 1, 1) }
          when "boolean"    then ot.guard(fld) { false                }
        end
      end

      def tc_bigdecimal(thing)
        Float(thing) # BigDecimal sucks at catching bad decimals
        BigDecimal(thing.to_s)
      end

      def tc_float(thing)
        Float(thing)
      end

      def tc_integer(thing)
        Integer(thing.to_s, 10)
      end

      def tc_date(thing)
        fail ArgumentError, "Can't cast Time to Date" if thing.is_a?(Time)
        thing.respond_to?(:to_date) ? thing.to_date : Date.parse(thing.to_s)
      end

      def tc_time(thing)
        thing.respond_to?(:to_time) ? thing.to_time : Time.parse(thing.to_s)
      end

      def tc_boolean(thing)
        return thing if thing == true || thing == false
        return true  if %w|true yes y on t 1|.include?(thing.to_s.downcase)
        return false if %w|false no n off f 0|.include?(thing.to_s.downcase)
        fail ArgumentError, "Cannot typecast string to Boolean"
      end

    end # of InstanceMethods

  end # of TypeCasting


end

