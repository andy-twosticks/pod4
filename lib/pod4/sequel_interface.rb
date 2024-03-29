require "octothorpe"

require_relative "interface"
require_relative "errors"
require_relative "connection"


module Pod4


  ##
  # Pod4 Interface for a Sequel table.
  #
  # If your DB table is one-one with your model, you shouldn't need to override anything.
  #
  # Example:
  #     class CustomerInterface < SwingShift::SequelInterface
  #       set_table  :customer
  #       set_id_fld :id
  #     end
  #
  # Data types: Sequel itself will translate to BigDecimal, Float, Integer, date, and datetime as
  # appropriate -- but it also depends on the underlying adapter.  TinyTds maps dates to strings,
  # for example. 
  #
  # Connections: Because the Sequel client -- the "DB" object -- has its own connection pool and
  # does most of the heavy lifting for us, the only reason we use the Connection class is to defer
  # creating the DB object until the first time we need it. Most of what Connection does, we don't
  # need, so our interactions with Connection are a little strange.
  #
  class SequelInterface < Interface

    attr_reader :id_fld

    class << self
      #---
      # These are set in the class because it keeps the model code cleaner: the definition of the
      # interface stays in the interface, and doesn't leak out into the model.
      #+++

      ##
      # Use this to set the schema name (optional)
      #
      def set_schema(schema)
        define_class_method(:schema) {schema.to_s.to_sym}
      end

      def schema; nil; end

      ##
      # Set the table name. 
      #
      def set_table(table)
        define_class_method(:table) {table.to_s.to_sym}
      end

      def table
        raise Pod4Error, "You need to use set_table to set the table name"
      end

      ##
      # Set the unique id field on the table.
      #
      def set_id_fld(idFld, opts={})
        ai = opts.fetch(:autoincrement) { true }
        define_class_method(:id_fld) {idFld.to_s.to_sym}
        define_class_method(:id_ai)  {!!ai}
      end

      def id_fld
        raise Pod4Error, "You need to use set_id_fld to set the ID column name"
      end

      def id_ai
        raise Pod4Error, "You need to use set_id_fld to set the ID column name"
      end

    end # of class << self

    ##
    # Initialise the interface by passing it the Sequel DB object. Or a Sequel
    # connection string. Or a Pod4::Connection object. 
    #
    def initialize(arg)
      raise(Pod4Error, 'no call to set_table in the interface definition') if self.class.table.nil?
      raise(Pod4Error, 'no call to set_id_fld in the interface definition') if self.class.id_fld.nil?

      case arg
        when Sequel::Database
          @connection = Connection.new(interface: self.class)
          @connection.data_layer_options = arg 

        when Hash, String
          @connection = Connection.new(interface: self.class)
          @connection.data_layer_options = Sequel.connect(arg)

        when Connection
          @connection = arg

        else
          raise ArgumentError, "Bad argument"

      end

      @sequel_version = Sequel.respond_to?(:qualify) ? 5 : 4
      @id_fld         = self.class.id_fld
      @db             = nil

    rescue => e
      handle_error(e)
    end

    def schema; self.class.schema; end
    def table;  self.class.table;  end
    def id_fld; self.class.id_fld; end
    def id_ai;  self.class.id_ai;  end

    def quoted_table
      if schema 
        %Q|#{db.quote_identifier schema}.#{db.quote_identifier table}|
      else
        db.quote_identifier(table)
      end
    end

    ##
    # Selection is whatever Sequel's `where` supports.
    #
    def list(selection=nil)
      sel = sanitise_hash(selection)
      Pod4.logger.debug(__FILE__) { "Listing #{self.class.table}: #{sel.inspect}" }

      (sel ? db_table.where(sel) : db_table.all).map {|x| Octothorpe.new(x) }
    rescue => e
      handle_error(e)
    end

    ##
    # Record is a Hash or Octothorpe of field: value
    #
    def create(record)
      raise Octothorpe::BadHash if record.nil?
      ot = Octothorpe.new(record)

      if id_ai
        ot = ot.reject{|k,_| k == id_fld}
      else
        raise(ArgumentError, "ID field missing from record") if ot[id_fld].nil?
      end

      Pod4.logger.debug(__FILE__) { "Creating #{self.class.table}: #{ot.inspect}" }

      id = db_table.insert( sanitise_hash(ot.to_h) )

      # Sequel doesn't return the key unless it is an autoincrement; otherwise it turns a row
      # number, which isn't much use to us. We always return the key.
      if id_ai
        id
      else
        ot[id_fld]
      end
    
    rescue Octothorpe::BadHash
      raise ArgumentError, "Bad type for record parameter"
    rescue
      handle_error $!
    end

    ##
    # ID corresponds to whatever you set in set_id_fld
    #
    def read(id)
      raise(ArgumentError, "ID parameter is nil") if id.nil?
      Pod4.logger.debug(__FILE__) { "Reading #{self.class.table} where #{@id_fld}=#{id}" }

      Octothorpe.new( db_table[@id_fld => id] )

    rescue Sequel::DatabaseError
      raise CantContinue, "Problem reading record. Is '#{id}' really an ID?"

    rescue => e
      handle_error(e)
    end

    ##
    # ID is whatever you set in the interface using set_id_fld record should be a Hash or
    # Octothorpe.
    #
    def update(id, record)
      read_or_die(id)

      Pod4.logger.debug(__FILE__) do 
        "Updating #{self.class.table} where #{@id_fld}=#{id}: #{record.inspect}"
      end

      db_table.where(@id_fld => id).update( sanitise_hash(record.to_h) )
      self
    rescue => e
      handle_error(e)
    end

    ##
    # ID is whatever you set in the interface using set_id_fld
    #
    def delete(id)
      read_or_die(id)

      Pod4.logger.debug(__FILE__) do
        "Deleting #{self.class.table} where #{@id_fld}=#{id}"
      end

      db_table.where(@id_fld => id).delete
      self
    rescue => e
      handle_error(e)
    end

    ##
    # Bonus method: execute arbitrary SQL. Returns nil.
    #
    def execute(sql)
      raise(ArgumentError, "Bad sql parameter") unless sql.kind_of?(String)
      Pod4.logger.debug(__FILE__) { "Execute SQL: #{sql}" }

      c = @connection.client(self)
      c.run(sql)

    rescue => e
      handle_error(e)
    end

    ##
    # Bonus method: execute SQL as per execute(), but parameterised.
    #
    # Use ? as a placeholder in the SQL
    # mode is either :insert :update or :delete
    # Sequel appears to quote these if you don't but bear in mind that, apparently,  symbols get
    # "quoted" as if they were columns while strings get 'quoted' as if they are, well, strings.
    #
    # "update and delete should return the number of rows affected, and insert should return the
    # autogenerated primary integer key for the row inserted (if any)"
    #
    def executep(sql, mode, *values)
      raise(ArgumentError, "Bad sql parameter")    unless sql.kind_of?(String)
      raise(ArgumentError, "Bad mode parameter")   unless %i|insert delete update|.include?(mode)
      Pod4.logger.debug(__FILE__) { "Parameterised execute #{mode} SQL: #{sql}" }

      @connection.client(self)[sql, *values].send(mode)
    rescue => e
      handle_error(e)
    end

    ## 
    # Bonus method: execute arbitrary SQL and return the resulting dataset as a Hash.
    #
    def select(sql)
      raise(ArgumentError, "Bad sql parameter") unless sql.kind_of?(String)
      Pod4.logger.debug(__FILE__) { "Select SQL: #{sql}" }

      @connection.client(self)[sql].all
    rescue => e
      handle_error(e)
    end

    ##
    # Bonus method: execute arbitrary SQL as per select(), but parameterised.
    #
    # Use ? as a placeholder in the SQL
    # Please quote values for yourself, we don't.
    #
    def selectp(sql, *values)
      raise(ArgumentError, "Bad sql parameter")    unless sql.kind_of?(String)
      Pod4.logger.debug(__FILE__) { "Parameterised select SQL: #{sql}" }

      @connection.client(self).fetch(sql, *values).all

    rescue => e
      handle_error(e)
    end

    ## 
    # Called by @connection to get the DB object.
    # Never called internally. Given the way Sequel works -- the data layer option object passed
    # to Connection actually is the client object -- we do something a bit weird here.
    #
    def new_connection(options)
      options
    end

    ###
    # Called by @connection to "close" the DB object.
    # Never called internally, and given the way Sequel works, we implement this as a dummy
    # operation
    #
    def close_connection
      self
    end

    ##
    # Return the connection object, for testing purposes only
    #
    def _connection
      @connection
    end

    private

    ##
    # Helper routine to handle or re-raise the right exception.
    #
    # Unless kaller is passed, we re-raise on the caller of the caller, which is likely the
    # original bug
    # 
    def handle_error(err, kaller=nil)
      kaller ||= caller[1..-1]

      Pod4.logger.error(__FILE__){ err.message }

      case err

        # Just raise the error as is
        when ArgumentError, 
             Pod4::Pod4Error, 
             Pod4::CantContinue

          raise err.class, err.message, kaller

        # Special Case for validation
        when Sequel::ValidationFailed,
             Sequel::UniqueConstraintViolation,
             Sequel::ForeignKeyConstraintViolation

          raise Pod4::ValidationError, err.message, kaller

        # This is more serious
        when Sequel::DatabaseError
          raise Pod4::DatabaseError, err.message, kaller

        # The default is to raise a generic Pod4 error.
        else
          raise Pod4::Pod4Error, err.message, kaller

      end

    end
    
    def sequel_fudges(db)
      # Work around a problem with jdbc-postgresql where it throws an exception whenever it sees
      # the money type. This workaround actually allows us to return a BigDecimal, so it's better
      # than using postgres_pr when under jRuby!
      if db.uri =~ /jdbc:postgresql/
        db.conversion_procs[790] = ->(s){BigDecimal(s[1..-1]) rescue nil}
        c = Sequel::JDBC::Postgres::Dataset

        if @sequel_version >= 5
          # In Sequel 5 everything is frozen, so some hacking is required.
          # See https://github.com/jeremyevans/sequel/issues/1458
          vals = c::PG_SPECIFIC_TYPES + [Java::JavaSQL::Types::DOUBLE] 
          c.send(:remove_const, :PG_SPECIFIC_TYPES) # We can probably get away with just const_set, but.
          c.send(:const_set,    :PG_SPECIFIC_TYPES, vals.freeze)
        else
          c::PG_SPECIFIC_TYPES << Java::JavaSQL::Types::DOUBLE
        end
      end

      db
    end

    ##
    # Sequel behaves VERY oddly if you pass a symbol as a value to the hash you give to a
    # selection,etc on a dataset. (It raises an error complaining that the symbol does not exist as
    # a column in the table...)
    #
    def sanitise_hash(sel)

      case sel
        when Hash
          sel.each_with_object({}) do |(k,v),m| 
            m[k] = v.kind_of?(Symbol) ? v.to_s : v 
          end

        when nil
          nil

        else 
          fail Pod4::DatabaseError, "Expected a selection hash, got: #{sel.inspect}"

      end

    end

    def read_or_die(id)
      raise CantContinue, "'No record found with ID '#{id}'" if read(id).empty?
    end

    def db
      if @db
        @db
      else
        @db = @connection.client(self)
        sequel_fudges(@db)
      end
    end

    def db_table

      if schema
        if @sequel_version == 5
          db[ Sequel[schema][table] ]
        else
          db[ "#{schema}__#{table}".to_sym ]
        end
      else
        db[table]
      end

    end

  end # of SequelInterface


end

