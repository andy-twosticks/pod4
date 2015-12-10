require 'nebulous'

require_relative 'interface'
require_relative 'errors'


module Pod4


  ##
  # An interface to talk to a Nebulous Target.
  #
  # Each interface can only speak with one target, designated with #set_target.
  # The developer must also set a unique ID key using #set_id_fld.
  #
  # The primary challenge here is to map the CRUDL methods (which interfaces
  # contract to implement) to nebulous verbs. The programmer uses #set_verb for
  # this purpose: the first parameter indicates the CRUDL method, the next is
  # the verb name, and the rest are hash keys.
  #
  # In the case of the #create and #update methods, the list of keys controls
  # which parts of the incoming hash end up in the verb parameters, and in what
  # order. For #update, the list must include the ID key that you gave to
  # #set_id_fld.  
  #
  # Parameters for the #list method similarly constrain how its selection
  # parameter is translated to a nebulous verb parameter string.  
  #
  # Parameters for #read and #delete can be whatever you like, but since the
  # only value passed to read is the ID, the only symbol there should be the
  # same as the one in #set_id_fld.
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
  # In this example both the create and update methods point to the same
  # nebulous verb. Note that only keys which are symbols are translated to the
  # corresponding values in the record or selection hash; anything else is
  # passed literally in the Nebulous parameter string.
  #
  # When you subclass NebulousInterfce, you may want to override some or all of
  # the CRUDL methods so that your callers can pass specific parameters rather
  # than a hash; the above example demonstrates this.
  #
  # We assume that the response to the #create message returns the ID as the
  # parameter part of the success verb. If that's not true, then you will have
  # to override #create and sort this out yourself.
  #
  class NebulousInterface < Interface

    # The NebResponse object from the last message sent, or nil otherwise
    attr_reader :response 
    
    # The status of the response from the last message: 
    # * nil - we didn't send a request yet
    # * :off - Nebulous is turned off, so nothing happened
    # * :timeout  we sent the message but timed out waiting for a response
    # * :verberror - we got an error verb in response 
    # * :verbsuccess - we got a success verb in response
    # * :response - we got some response that doesn't follow The Protocol
    #
    # NB: if we got an exception sending the message, we raised it on the
    # caller, so there is no status for that.
    attr_reader :response_status


    Verb = Struct.new(:name, :params)


    class << self
      attr_reader :target, :verbs, :id_fld

      #--
      # These are set in the class because it keeps the model code cleaner: the
      # definition of the interface stays in the interface, and doesn't leak
      # out into the model.
      #++

      ##
      # Set a verb. 
      # * action - must be one of CRUDL
      # * verb - the name of the verb
      # * parameters - array of symbols to order the hash passed to create, etc
      #
      def set_verb(action, verb, *paramKeys)
        raise ArgumentError, "bad action" \
          unless Interface::ACTIONS.include? action

        @verbs ||= {}
        @verbs[action] = Verb.new( verb, paramKeys.flatten )
      end

      ##
      # Set the name of the Nebulous target in the interface definition
      #
      def set_target(target); @target = target; end
      
      ##
      # Set the name of the ID parameter (needs to be in CRUD verbs param list)
      #
      def set_id_fld(idFld); @id_fld = idFld; end 

      ##
      # Make sure all of the above is consistent
      #
      def validate_params
        raise Pod4Error, "You need to use set_target" unless @target
        raise Pod4Error, "You need to use set_id_fld" unless @id_fld
        raise Pod4Error, "You need to use set_verb"   if @verbs.nil?

        %i|create read update delete|.each do |action|
          raise Pod4Error, "set_verb #{action} is missing a parameter list" \
            if @verbs[action] && !@verbs[action].params == []

        end

        %i|read update delete|.each do |action|
          raise Pod4Error, "#{action} verb doesn't have an #@id_fld key" \
            if @verbs[action] && !@verbs[action].params.include?(@id_fld)

        end

      end


    end
    ##


    ##
    # In normal operation, takes no parameters.
    #
    # For testing purposes you may pass an instance of a class here. It must
    # respond to a #send method with parameters (verb, parameter string, cache
    # yes/no) by returning some kind of NebRequest (presumably either a double
    # or an instance of NebRequestNull). This method will be called instead of
    # creating a NebRequest directly.
    #
    def initialize(requestObj=nil)
      @request_object  = requestObj
      @response        = nil
      @response_status = nil
      @id_fld          = self.class.id_fld

      self.class.validate_params
    end


    ##
    # Pass a parameter string or array (which will be taken as the literal
    # Nebulous parameter) or a Hash or Octothorpe (which will be interpreted as
    # per your list of keys set in add_verb :list).
    #
    # Returns an array of Octothorpes, or an empty array if the responder could
    # not make any records out of our message.
    #
    def list(selection=nil)
      sel = 
        case selection
          when Array, Hash, Octothorpe then param_string(:list, selection)
          else selection
        end

      send_message( verb_for(:list), sel )

      @response.body_to_h # should be an array irrespective of the method name
          .map{|e| Octothorpe.new(e) }

    rescue => e
      handle_error(e)
    end


    ##
    # Pass a parameter string or an array as the record. returns the ID.
    # We assume that the response to the create message returns the ID as the
    # parameter part of the success verb. If that's not true, then you will
    # have to override #create and sort this out yourself.
    #
    def create(record)
      raise ArgumentError, 'create takes a Hash or an Octothorpe' \
        unless record.kind_of?(Hash) || record.kind_of?(Octothorpe)

      send_message( verb_for(:create), param_string(:create, record) )

      @response.params

    rescue => e
      handle_error(e)
    end


    ##
    # Given the id, return an Octothorpe of the record.
    #
    # The actual parameters passed to nebulous depend on how you #set_verb
    #
    def read(id)
      raise ArgumentError, 'You must pass an ID to read' unless id

      send_message( verb_for(:read), param_string(:read, nil, id) )

      Octothorpe.new( @response.body_to_h )
    end


    ##
    # Given an id an a record (Octothorpe or Hash), update the record.  Returns
    # self.
    #
    def update(id, record)
      raise ArgumentError, 'You must pass an ID to update' unless id
      raise ArgumentError, 'update record takes a Hash or an Octothorpe' \
        unless record.kind_of?(Hash) || record.kind_of?(Octothorpe)

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
    # Bonus method: chain this method before a CRUDL method to clear the cache
    # for that parameter string:
    #     @interface.clearing_cache.read(14)
    #
    def clearing_cache
      @clear_cache = true
      self
    end


    ##
    # Bonus method: send an arbitrary Nebulous message to the target and return
    # the response object.
    #
    # We don't trap errors here - see #handle_error - but we raise extra ones
    # if we think things look fishy.
    #
    def send_message(verb, paramStr, with_cache=true)
      unless Nebulous.on? 
        @response_status = :off
        raise Pod4::DatabaseError, "Nebulous is turned off!"
      end

      @response = send_message_helper(verb, paramStr, with_cache)

      raise Pod4::DatabaseError, "Null response" if @response.nil?

      @response_status = 
        case @response.verb
          when 'error'   then :verberror
          when 'success' then :verbsuccess
          else                :response
        end

      raise Pod4::DatabaseError, "Nebulous returned an error verb" \
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
    # Work out the parameter string based on the corresponding #set_Verb call.
    # Insert the ID value if given
    #
    def param_string(action, hashParam, id=nil)
      hash = hashParam ? hashParam.dup : {}

      hash[@id_fld] = id.to_s if id

      para = self.class.verbs[action].params.map do |p| 
        p.kind_of?(Symbol) ? hash[p] : p 
      end

      para.join(',')
    end


    ##
    # Deal with any exceptions that are raised.
    #
    # Our contract says that we should throw errors to the model, but those
    # errors should be Pod4 errors. 
    #
    def handle_error(err)
      Pod4.logger.error(__FILE__){ err.message }

      case err
        when ArgumentError, Pod4::Pod4Error
          raise err

        when Nebulous::NebulousTimeout
            @response_status = :timeout
            raise Pod4::DatabaseError.from_error(err)

        when Nebulous::NebulousError
          raise Pod4::DatabaseError.from_error(err)

        else
          raise Pod4::Pod4Error.from_error(err)

      end

    end


    ##
    # A little helper method to create a response object (unless we were given
    # one for testing purposes), clear the cache if we are supposed to, and
    # then send the message.
    #
    # returns the response to the request.
    #
    def send_message_helper(verb, paramStr, with_cache)
      request = 
        if @request_object
          @request_object.send(verb, paramStr, with_cache)
        else
          Nebulous::NebRequest.new(self.class.target, verb, paramStr)
        end

      if @clear_cache
        request.clear_cache
        @clear_cache = false
      end

      with_cache ? request.send : request.send_no_cache
    end


  end


end
