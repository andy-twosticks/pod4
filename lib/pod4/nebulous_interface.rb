require 'nebulous'

require 'core/lib/interface'


module SwingShift


  ##
  # An interface to talk to a Nebulous Target. 
  #
  # When you subclass this you may want to override list, read, create etc
  # to respond to specific parameters rather than just accepting an abstract
  # OT.
  #
  # Example:
  #     class CustomerInterface < SwingShift::NebulousInterface
  #       set_verb :read, 'customerread'
  #       set_verb :list, 'customerlist'
  #
  #       def list(region, type)
  #         super( [region,type] )
  #       end
  #     end
  #
  class NebulousInterface < SwingShift::Interface

    # The NebResponse object from the last message sent, or nil otherwise
    attr_reader :response

    # The status of the response from the last message: 
    # * :off - Nebulous is turned off, so nothing happened
    # * :error - something bad happenned when we tried to send the message
    # * :timeout  we sent the message but timed out waiting for a response
    # * :verberror - we got an error verb in response 
    # * :verbsuccess - we got a success verb in response
    # * :response - we got some response that doesn't follow The Protocol
    attr_reader :status


    class << self
      attr_reader :target, :verbs

      # ---
      # These are set in the class because it keeps the model code cleaner: the
      # definition of the interface stays in the interface, and doesn't leak
      # out into the model.
      # +++

      ##
      # Set the verb names for each CRUDL action in the interface definition
      #
      def set_verb(action, verb)
        raise "bad action" unless SwingShift::Interface::ACTIONS.include? action

        @verbs ||= {}
        @verbs[action] = verb
      end

      ##
      # Set the name of the Nebulous target in the interface definition
      #
      def set_target(target); @target = target; end
    end
    ##


    ##
    # Pass the Nebulous connection hash into the model to initialise it
    #
    def initialize(paramHash)
      @param_hash = paramHash
      @status     = nil
      @response   = nil
    end


    ##
    # Pass a parameter string or array; returns an array of hashes
    # Whether this can be turned into a model record is in the hands of the
    # Responder, not us.
    #
    def list(selection=nil)
      send_message( verb_for(:list), param_string(selection) )

      @response.body_to_a #bamf, Nebulous method is missing...!
          .map{|e| Octothorpe.new(e) }

    rescue => e
      handle_error(e)
    end


    ##
    # Pass a parameter string or an array as the record
    #
    def create(record)
      send_message( verb_for(:create), param_string(record), false )
      self
    rescue => e
      handle_error(e)
    end


    ##
    # We assume that the parameter string for the read verb is just the ID
    #
    def read(id)
      send_message( verb_for(:read), param_string(id) )
      Octothorpe.new( @response.body_to_h )
    rescue => e
      handle_error(e)
    end


    ##
    # We assume that the ID is the first parameter; pass the rest in record as
    # a string or an array.
    #
    def update(id, record)
      paramStr = param_string(record)
      send_message( verb_for(:update), "#{id},#{paramStr}", false )
      self
    end


    ##
    # We assume that the parameter string for delete is just the ID
    #
    def delete(id)
      send_message( verb_for(:delete), param_string(id), false )
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
    # ---
    # Note that we lack the testing SmartArsery we had with a proc in SS1.
    # Which didn't work well. We need to solve this in the Nebulous gem, then
    # implement ... something ... here.
    #
    # Also, BAMF, we need to throw SS errors here...
    # +++
    #
    def send_message(verb, paramStr, with_cache=true)
      if PARAMS[:nebulous].nil? # Nebulous turned off
        @status = :off
        return self
      end

      request = Nebulous::RebRequest.new( self.class.target, verb, paramStr)

      if @clear_cache
        request.clear_cache
        @clear_cache = false
      end

      @response = with_cache ? request.send : request.send_no_cache
      raise Nebulous::NebulousError, "Null response" if @response.body_to_h.nil?

      set_status
      self
    end


    private


    def verb_for(action)
      self.class.verbs[action]
    end


    def param_string(params)
      return '' if params.nil?
      params.kind_of?(Array) ? params.join(',') : params.to_s
    end


    # ...and here. bamf.
    def handle_error(err)
      case err
      when Nebulous::NebulousTimeout
          @status = :timeout
      when Nebulous::NebulousError
          @status = :error
      end
    end


    def set_status
      @status =
        case @response.verb
          when 'error'   then :verberror
          when 'success' then :verbsuccess
          else :response
        end
    end

  end


end
