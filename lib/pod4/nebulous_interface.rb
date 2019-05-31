require_relative "interface"
require_relative "errors"


module Pod4


  ##
  # An interface to talk to a Nebulous Target.
  #
  # Each interface can only speak with one target, designated with #set_target. The developer must
  # also set a unique ID key using #set_id_fld.
  #
  # The primary challenge here is to map the CRUDL methods (which interfaces contract to implement)
  # to nebulous verbs. The programmer uses #set_verb for this purpose: the first parameter
  # indicates the CRUDL method, the next is the verb name, and the rest are hash keys.
  #
  # In the case of the #create and #update methods, the list of keys controls which parts of the
  # incoming hash end up in the verb parameters, and in what order. For #update, the list must
  # include the ID key that you gave to #set_id_fld.  
  #
  # Parameters for the #list method similarly constrain how its selection parameter is translated
  # to a nebulous verb parameter string.  
  #
  # Parameters for #read and #delete can be whatever you like, but since the only value passed to
  # read is the ID, the only symbol there should be the same as the one in #set_id_fld.
  #
  #     class CustomerInterface < SwingShift::NebulousInterface
  #       set_target 'accord'
  #       set_id_fld :id
  #       set_verb :read,   'customerread',   :id, '100'
  #       set_verb :list,   'customerlist',   :name
  #       set_verb :create, 'customerupdate', 'create', :name, :price
  #       set_verb :update, 'customerupdate', 'update', :name, :id, :price
  #
  #       def update(id, name, price)
  #         super( id, name: name, price: price)
  #       end
  #     end
  #
  # In this example both the create and update methods point to the same nebulous verb. Note that
  # only keys which are symbols are translated to the corresponding values in the record or
  # selection hash; anything else is passed literally in the Nebulous parameter string.
  #
  # When you subclass NebulousInterface, you may want to override some or all of the CRUDL methods
  # so that your callers can pass specific parameters rather than a hash; the above example
  # demonstrates this.
  #
  # We assume that the response to the #create message returns the ID as the parameter part of the
  # success verb. If that's not true, then you will have to override #create and sort this out
  # yourself.
  #
  # Calls to create, update and delete avoid (for obvious reasons) Nebulous' Redis cache if
  # present. Read and list use it, but can take an extra options hash to control it, which, of
  # course, Pod4::Model does not know about. If you want to enable a non-cached read in your model,
  # it will need a method something like this:
  #
  #     def read_no_cache
  #       r = interface.read(@model_id, caching: false)
  #
  #       if r.empty?
  #         add_alert(:error, "Record ID '#@model_id' not found on the data source")
  #       else
  #         map_to_model(r)
  #         run_validation(:read)
  #         @model_status = :okay if @model_status == :empty
  #       end
  #
  #       self
  #     rescue Pod4::WeakError
  #       add_alert(:error, $!)
  #       self
  #     end
  #
  # NB: Connections: Nebulous does not use the Connection class. The user must configure
  # NebulousStomp themselves, once, when their application starts; but they don't need to do this
  # before requiring the models. And there is no need for a connection pool.
  #
  class NebulousInterface < Interface

    attr_reader :id_fld, :id_ai

    # The NebulousStomp Message object holding the response from the last message sent, or, nil.
    attr_reader :response 
    
    # The status of the response from the last message: 
    # * nil - we didn't send a request yet
    # * :off - Nebulous is turned off, so nothing happened
    # * :timeout  we sent the message but timed out waiting for a response
    # * :verberror - we got an error verb in response 
    # * :verbsuccess - we got a success verb in response
    # * :response - we got some response that doesn't follow The Protocol
    #
    # NB: if we got an exception sending the message, we raised it on the caller, so there is no
    # status for that.
    attr_reader :response_status

    Verb = Struct.new(:name, :params)


    class << self
      #--
      # These are set in the class because it keeps the model code cleaner: the definition of the
      # interface stays in the interface, and doesn't leak out into the model.
      #++

      ##
      # Set a verb. 
      # * action - must be one of CRUDL
      # * verb - the name of the verb
      # * parameters - array of symbols to order the hash passed to create, etc
      #
      def set_verb(action, verb, *paramKeys)
        raise ArgumentError, "Bad action" unless Interface::ACTIONS.include? action

        v = verbs.dup
        v[action] = Verb.new( verb, paramKeys.flatten )

        define_class_method(:verbs) {v}
      end

      def verbs; {}; end

      ##
      # Set the name of the Nebulous target in the interface definition
      #
      # a reference to the interface object.
      #
      def set_target(target)
        define_class_method(:target) {target.to_s}
      end

      def target
        raise Pod4Error, "You need to use set_target on your interface"
      end

      ##
      # Set the name of the ID parameter (needs to be in the CRUD verbs param list)
      def set_id_fld(idFld, opts={})
        ai = opts.fetch(:autoincrement) { true }
        define_class_method(:id_fld) {idFld}
        define_class_method(:id_ai)  {!!ai}
      end

      def id_fld
        raise Pod4Error, "You need to use set_id_fld"
      end

      def id_ai
        raise Pod4Error, "You need to use set_id_fld"
      end

      ##
      # Make sure all of the above is consistent
      #
      def validate_params
        raise Pod4Error, "You need to use set_verb" if verbs == {}

        %i|create read update delete|.each do |action|
          raise Pod4Error, "set_verb #{action} is missing a parameter list" \
            if verbs[action] && !verbs[action].params == []

        end

        %i|read update delete|.each do |action|
          raise Pod4Error, "#{action} verb doesn't have an #{id_fld} key" \
            if verbs[action] && !verbs[action].params.include?(id_fld)

        end

      end

    end # of class << self

    ##
    # In normal operation, takes no parameters.
    #
    # For testing purposes you may pass something here. Whatever it is you pass, it must respond to
    # a `send` method, take the same parameters as NebulousStomp::Request.new (that is, a
    # target and a message) and return something that behaves like a NebulousStomp::Request.
    # This method will be called instead of creating a NebulousStomp::Request directly.
    #
    def initialize(requestObj=nil)
      @request_object  = requestObj # might as well be a reference 
      @response        = nil
      @response_status = nil
      @id_fld          = self.class.id_fld
      @id_ai           = self.class.id_ai

      self.class.validate_params
    end

    ##
    # Pass a parameter string or array (which will be taken as the literal Nebulous parameter) or a
    # Hash or Octothorpe (which will be interpreted as per your list of keys set in add_verb
    # :list).
    #
    # Returns an array of Octothorpes, or an empty array if the responder could not make any
    # records out of our message.
    #
    # Note that the `opts` hash is not part of the protocol supported by Pod4::Model. If you want
    # to make use of it, you will have to write your own method for that. Supported keys:
    #
    # * caching: true if you want to use redis caching (defaults to true)
    #
    def list(selection=nil, opts={})
      sel = 
        case selection
          when Array, Hash, Octothorpe then param_string(:list, selection)
          else selection
        end

      caching = opts[:caching].nil? ? true : !!opts[:caching]
      send_message( verb_for(:list), sel, caching )
      @response.body.is_a?(Array) ? @response.body.map{|e| Octothorpe.new e} : []

    rescue => e
      handle_error(e)
    end

    ##
    # Pass a parameter string or an array as the record. returns the ID. We assume that the
    # response to the create message returns the ID as the parameter part of the success verb. If
    # that's not true, then you will have to override #create and sort this out yourself.
    #
    def create(record)
      raise ArgumentError, 'create takes a Hash or an Octothorpe' unless hashy?(record)

      raise ArgumentError, "ID field missing from record" \
        if !@id_ai && record[@id_fld].nil? && record[@id_fld.to_s].nil?

      send_message( verb_for(:create), param_string(:create, record), false )
      @response.params

    rescue => e
      handle_error(e)
    end

    ##
    # Given the id, return an Octothorpe of the record.
    #
    # The actual parameters passed to nebulous depend on how you #set_verb
    #
    # Note that the `opts` hash is not part of the protocol supported by Pod4::Model. If you want
    # to make use of it, you will have to write your own method for that. Supported keys:
    #
    # * caching: true if you want to use redis caching (defaults to true)
    #
    def read(id, opts={})
      raise ArgumentError, 'You must pass an ID to read' unless id

      caching = opts[:caching].nil? ? true : !!opts[:caching]
      send_message( verb_for(:read), 
                    param_string(:read, nil, id), 
                    caching )

      Octothorpe.new( @response.body.is_a?(Hash) ? @response.body : {} )
    end

    ##
    # Given an id an a record (Octothorpe or Hash), update the record. Returns self.
    #
    def update(id, record)
      raise ArgumentError, 'You must pass an ID to update' unless id
      raise ArgumentError, 'update record takes a Hash or an Octothorpe' unless hashy?(record)

      send_message( verb_for(:update), 
                    param_string(:update, record, id), 
                    false )

      self
    end

    ##
    # Given an ID, delete the record. Return self.
    #
    # The actual parameters passed to nebulous depend on how you #set_verb
    #
    def delete(id)
      raise ArgumentError, 'You must pass an ID to delete' unless id

      send_message( verb_for(:delete), 
                    param_string(:delete, nil, id), 
                    false )

      self
    end
    
    ##
    # Bonus method: chain this method before a CRUDL method to clear the cache for that parameter
    # string:
    #
    #     @interface.clearing_cache.read(14)
    #
    # Note that there is no guarantee that the request that clears the cache is actually the one
    # you chain after (if multiple model instances are running against the same interface instance)
    # but for the instance that calls `clearing_cache`, this is not important.
    #
    def clearing_cache
      @clear_cache = true
      self
    end

    
    ##
    # Bonus method: send an arbitrary Nebulous message to the target and return the response object.
    #
    # We don't trap errors here - see #handle_error - but we raise extra ones if we think things
    # look fishy.
    #
    def send_message(verb, paramStr, with_cache=true)
      unless NebulousStomp.on? 
        @response_status = :off
        raise Pod4::DatabaseError, "Nebulous is turned off!"
      end

      Pod4.logger.debug(__FILE__) do
        "Sending v:#{verb} p:#{paramStr} c?: #{with_cache}"
      end

      @response = send_message_helper(verb, paramStr, with_cache)

      raise Pod4::DatabaseError, "Null response" if @response.nil?

      @response_status = 
        case @response.verb
          when 'error'   then :verberror
          when 'success' then :verbsuccess
          else                :response
        end

      raise Pod4::WeakError, "Nebulous returned an error verb: #{@response.description}" \
        if @response_status == :verberror

      self

    rescue => err
      handle_error(err)
    end

    private

    ##
    # Given :create, :read, :update, :delete or :list, return the Nebulous verb
    #
    def verb_for(action)
      self.class.verbs[action].name
    end

    ##
    # Work out the parameter string based on the corresponding #set_Verb call. Insert the ID value
    # if given
    #
    def param_string(action, hashParam, id=nil)
      hash = hashParam.nil? ? {} : hashParam.to_h

      hash[@id_fld] = id.to_s if id

      para = self.class.verbs[action].params.map do |p| 
        p.kind_of?(Symbol) ? hash[p] : p 
      end

      para.join(',')
    end

    ##
    # Deal with any exceptions that are raised.
    #
    # Our contract says that we should throw errors to the model, but those errors should be Pod4
    # errors. 
    #
    def handle_error(err, kaller=caller[1..-1])
      Pod4.logger.error(__FILE__){ err.message }

      case err
        when ArgumentError, Pod4::Pod4Error
          raise err.class, err.message, kaller

        when NebulousStomp::NebulousTimeout
            @response_status = :timeout
            raise Pod4::CantContinue, err.message, kaller

        when NebulousStomp::NebulousError
          raise Pod4::DatabaseError, err.message, kaller

        else
          raise Pod4::Pod4Error, err.message, kaller

      end

    end

    ##
    # A little helper method to create a response object (unless we were given one for testing
    # purposes), clear the cache if we are supposed to, and then send the message.
    #
    # returns the response to the request.
    #
    def send_message_helper(verb, paramStr, with_cache)
      message = NebulousStomp::Message.new(verb: verb, params: paramStr)
      request = 
        if @request_object
          @request_object.send(self.class.target, message)
        else
          NebulousStomp::Request.new(self.class.target, message)
        end

      if @clear_cache
        request.clear_cache
        @clear_cache = false
      end

      with_cache ? request.send : request.send_no_cache
    end

    def hashy?(obj)
      obj.kind_of?(Hash) || obj.kind_of?(Octothorpe)
    end

  end # of NebulousInterface


end
