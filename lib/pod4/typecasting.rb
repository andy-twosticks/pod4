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
    end
    ##


    module InstanceMethods

      def map_to_model(ot)
        enc = self.class.encoding
        
        ot.each do |_,v| 
          v.force_encoding(enc) if v.kind_of?(String) && enc
        end

        super(ot)
      end

    end
    ##

  end


end

