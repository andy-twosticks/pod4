require 'pod4/errors'
require 'pod4/metaxing'


module Pod4


  ##
  # A mixin that extends the model DSL to simplify use of custom interface methods.
  #
  # We add one command to the model DSL: set_custom_list. It's optional.
  #
  #
  # set_custom_list
  # ---------------
  #
  #     class Bar < Pod4::Model
  #       include Pod4::Tweaking
  # 
  #       class Interface < Pod4::PgInterface
  #         set table :bar
  #         set_id_field :id, autoincrement: true
  # 
  #         # Example custom interface method
  #         def list_paged(drop=0, limit=15)
  #           execute %Q|select * from bar offset #{drop} rows fetch next #{limit} rows only;|
  #         end
  #       end # of Interface
  # 
  #       set_interface   Interface.new($conn)
  #       set_custom_list :list_paged
  #     end
  #
  # Use this when you want to make a special version of the List action.  It takes one parameter:
  # the name of a custom method you have defined on the Interface. A corresponding method will be
  # created on the model. Any parameters you pass to the model method will be passed on to your
  # custom interface method.
  #
  # Your custom interface method should return an array of Octothorpes or Hashes; the
  # corresponding model method will return an array of instances of the model, just as #list does.
  #
  # Obviously this means that the keys in your array of Hash/Octothorpe must match the column
  # attributes in the model.  Any missing attributes will be set to nil; any extra attributes will
  # be ignored.  But the ID field must be present as a key, or else an exception will be raised. if
  # you want to indicate that no records were found, you must return an empty Array and not nil.
  #
  # Just as with List proper, the array of model instances have not had validation run against
  # them, and are all status :empty.
  #
  module Tweaking

    ##
    # A little bit of magic, for which I apologise. 
    #
    # When you include this module it actually adds the methods in ClassMethods to the class as if
    # you had called `extend TypeCasting:ClassMethds` *AND* (theoretically, in this case) adds the
    # methods in InstanceMethods as if you had written `prepend TypeCasting::InstanceMethods`.  
    #
    # In my defence: I didn't want to have to make you remember to do that...
    #
    def self.included(base)
      base.extend ClassMethods
#     base.send(:prepend, InstanceMethods)
    end


    module ClassMethods
      include Metaxing

      def set_custom_list(method)
        raise ArgumentError, "Bad custom interface method" unless interface.respond_to?(method)
        raise ArgumentError, "Method already exists on the model" \
          if (self.instance_methods - self.class.instance_methods).include?(method)

        define_class_method(method) do |*args|
          mname = "#{interface.class.name}.#{method}"
          rows  = interface.send(method, *args)

          raise Pod4Error, "#{mname} did not return an array" unless rows.is_a? Array
          raise Pod4Error, "#{mname} did not return an array of records" \
            unless rows.all?{|r| r.is_a?(Hash) || r.is_a?(Octothorpe) }

          raise Pod4Error, "#{mname} returned some records with no ID" \
            unless rows.all?{|r| r.has_key? interface.id_fld }

          rows.map do |r|
            rec = self.new r[interface.id_fld] 
            rec.map_to_model r 
            rec
          end
        end

      end

    end # of ClassMethods


#   module InstanceMethods
#   end # of InstanceMethods

  end # of Tweaking


end

