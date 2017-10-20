require 'BigDecimal'
require 'Time'
require 'pod4/errors'
require 'pod4/metaxing'


module Pod4


  ##
  # A mixin to give you some more options to control how Pod4 maps the interface to the model.
  #
  # Eventually we will actually have typecasting in here. For now all this allows you to do is
  # enforce an encoding -- which will be of use if you are dealing with MSSQL, or with certain
  # interfaces which appear to deal with the code page poorly:
  #
  #     class FOo < Pod4::Model
  #       include Pod4::TypeCasting
  #
  #       force_encoding Encoding::UTF-8
  #
  #       ...
  #     end
  #
  module TypeCasting

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

      def typecast(*flds, options={})
        raise Pod4Error, "Bad Typecasting" unless options.keys.any?{|o| %i|as use|.include? o}

        c = typecasts.dup
        flds.each do |f| 
          c[f] = options
          attr_reader f unless columns.include? f
        end

        define_class_method(:typecasts) {c}
      end

      def typecasts; {}; end

    end
    ##


    module InstanceMethods

      def map_to_model(ot)
        enc = self.class.encoding
        
        ot.each_value do |v|
          v.force_encoding(enc) if v.kind_of?(String) && enc
        end

        super(ot)
      end

      def set(ot)
        hash = _typecast(ot)
        super(ot.merge hash)
      end

      def to_interface
        ot   = super
        hash = _typecast(ot, :strict)
        ot.merge hash
      end

      def to_ot
        ot = super
        ot.each_key do |k|
          next unless (tc = self.class.typecasts[k])
          _guard(k, tc)
        end

        ot
      end

      # This is ugly
      #
      def typecast(type, thing, opt=nil)
        return thing if type.is_a?(Class) && thing.is_a?(type)
        return nil   if thing.to_s.blank?

        if type == BigDecimal
          Float(thing) # BigDecimal sucks at catching bad decimals
          return BigDecimal.new(thing.to_s)

        elsif type == Float
          return Float(thing)

        elsif type == Integer 
          return Integer(thing.to_s, 10)

        elsif type == Date
          return thing.to_date if thing.respond_to?(:to_date)
          return Date.parse(thing.to_s)

        elsif type == Time
          return thing.to_time if thing.respond_to?(:to_time)
          return Time.parse(thing.to_s)

        elsif type == :boolean
          return thing if thing == true || thing == false
          return true  if %w|true yes y on|.include?(thing.to_s.downcase)
          return false if %w|false no n off|.include?(thing.to_s.downcase)
          raise ArgumentError, "Cannot typecast string to Boolean"

        else 
          fail Pod4Error, "Bad type passed to typecast()"
        end
      rescue ArgumentError
        return (opt == :strict ? nil : thing)
      end

      def typecast?(attr)
        fail Pod4Error, "Unknown column passed to typecast?()" \
          unless (tc = self.class.typecasts[attr])

        !!typecast_one(attr, tc)
      end

      private

      def _typecast(ot, strict=nil)
        hash = {}
        ot.each_key do |k|
          next unless (tc = self.class.typecasts[k])
          hash[k] = _typecast_one(k, tc)
        end

        hash
      end

      def _typecast_one(fld, tc)
        val = instance_variable_get("@#{fld}".to_sym)
        tc[:as] ? typecast(tc[:as], val, strict) : tc[:use](val, strict)
      end

      def _guard(fld, tc)
        return unless tc[:as]

        if tc[:as] == :boolean
          ot.guard(fld) {false}
        else
          ot.guard tc[:as], fld
        end
      end

    end
    ##

  end


end

