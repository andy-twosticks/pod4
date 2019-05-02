require "octothorpe"
require "date"
require "time"
require "bigdecimal"

require_relative "interface"
require_relative "connection_pool"
require_relative "errors"
require_relative "sql_helper"


module Pod4

  
  ##
  # Pod4 Interface for requests on a SQL table via pg, the PostgresQL adapter.
  #
  # If your DB table is one-one with your model, you shouldn't need to override anything.
  # Example:
  #
  #     class CustomerInterface < SwingShift::PgInterface
  #       set_schema :public    # optional
  #       set_table  :customer
  #       set_id_fld :id, autoincrement: true
  #     end
  #
  class PgInterface < Interface
    include SQLHelper

    attr_reader :id_fld

    class << self
      #--
      # These are set in the class because it keeps the model code cleaner: the definition of the
      # interface stays in the interface, and doesn't leak out into the model.
      #++

      ## 
      # Set the name of the schema. This is optional.
      # 
      def set_schema(schema) 
        define_class_method(:schema) {schema.to_s.to_sym}
      end

      def schema; nil; end
        

      ##
      # Set the name of the database table
      #
      def set_table(table)
        define_class_method(:table) {table.to_s.to_sym}
      end

      def table
        raise Pod4Error, "You need to use set_table to set the table name"
      end


      ##
      # Set the name of the column that holds the unique id for the table.
      #
      def set_id_fld(idFld, opts={})
        ai = opts.fetch(:autoincrement) { true }
        define_class_method(:id_fld) {idFld.to_s.to_sym}
        define_class_method(:id_ai)  {!!ai}
      end

      def id_fld
        raise Pod4Error, "You need to use set_id_fld to set the ID column"
      end

      def id_ai
        raise Pod4Error, "You need to use set_id_fld to set the ID column"
      end

    end # of class << self

    ##
    # Initialise the interface by passing it a Pg connection hash, or a Pod4::ConnectionPool
    # object.
    #
    def initialize(arg)
      case arg
        when Hash
          @connection = ConnectionPool.new(interface: self.class)
          @connection.data_layer_options = arg

        when ConnectionPool
          @connection = arg

        else
          raise ArgumentError, "Bad argument"
      end

    rescue => e
      handle_error(e)
    end

    def schema; self.class.schema; end
    def table;  self.class.table;  end
    def id_fld; self.class.id_fld; end
    def id_ai;  self.class.id_ai;  end

    def list(selection=nil)
      raise(ArgumentError, 'selection parameter is not a hash') \
        unless selection.nil? || selection.respond_to?(:keys)

      sql, vals = sql_select(nil, selection)
      selectp(sql, *vals) {|r| Octothorpe.new(r) }

    rescue => e
      handle_error(e)
    end

    ##
    # Record is a hash or octothorpe of field: value
    #
    # By a happy coincidence, insert returns the unique ID for the record, which is just what we
    # want to do, too.
    #
    def create(record)
      raise Octothorpe::BadHash if record.nil?
      ot = Octothorpe.new(record)

      if id_ai
        ot = ot.reject{|k,_| k == id_fld}
      else
        raise(ArgumentError, "ID field missing from record") if ot[id_fld].nil?
      end

      sql, vals = sql_insert(ot) 
      x = selectp(sql, *vals)
      x.first[id_fld]

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

      sql, vals = sql_select(nil, id_fld => id) 
      rows = selectp(sql, *vals)
      Octothorpe.new(rows.first)

    rescue => e
      # Select has already wrapped the error in a Pod4Error, but in this case we want to catch
      # something. Ruby 2.0 doesn't define Exception.cause, but in that case, we do on Pod4Error.
      raise CantContinue, "That doesn't look like an ID" \
        if e.respond_to?(:cause) && e.cause.class == PG::InvalidTextRepresentation

      handle_error(e)
    end

    ##
    # ID is whatever you set in the interface using set_id_fld; record should be a Hash or
    # Octothorpe.
    #
    def update(id, record)
      raise(ArgumentError, "Bad type for record parameter") \
        unless record.kind_of?(Hash) || record.kind_of?(Octothorpe)

      read_or_die(id)

      sql, vals = sql_update(record, id_fld => id)
      executep(sql, *vals)

      self

    rescue => e
      handle_error(e)
    end

    ##
    # ID is whatever you set in the interface using set_id_fld
    #
    def delete(id)
      read_or_die(id)

      sql, vals = sql_delete(id_fld => id)
      executep(sql, *vals)

      self

    rescue => e
      handle_error(e)
    end

    ##
    # Run SQL code on the server. Return the results.
    #
    # Will return an array of records, or you can use it in block mode, like this:
    #
    #     select("select * from customer") do |r|
    #       # r is a single record
    #     end
    #
    # The returned results will be an array of hashes (or if you passed a block, of whatever you
    # returned from the block).
    #
    def select(sql)
      raise(ArgumentError, "Bad SQL parameter") unless sql.kind_of?(String)

      client = ensure_connection
      Pod4.logger.debug(__FILE__){ "select: #{sql}" }

      rows = []
      client.exec(sql) do |query|
        oids = make_oid_hash(query)

        query.each do |r| 
          row = cast_row_fudge(r, oids)

          if block_given? 
            rows << yield(row)
          else
            rows << row
          end

        end
      end

      client.cancel 
      rows

    rescue => e
      handle_error(e)
    end

    ##
    # Run SQL code on the server as per select() but with parameter insertion.
    #
    # Placeholders in the SQL string should all be %s as per sql_helper methods.
    # Values should be as returned by sql_helper methods.
    #
    def selectp(sql, *vals)
      raise(ArgumentError, "Bad SQL parameter") unless sql.kind_of?(String)

      client = ensure_connection
      Pod4.logger.debug(__FILE__){ "select: #{sql} #{vals.inspect}" }

      rows = []
      client.exec_params( *parse_for_params(sql, vals) ) do |query|
        oids = make_oid_hash(query)

        query.each do |r| 
          row = cast_row_fudge(r, oids)

          if block_given? 
            rows << yield(row)
          else
            rows << row
          end

        end
      end

      client.cancel 
      rows

    rescue => e
      handle_error(e)
    end

    ##
    # Run SQL code on the server; return true or false for success or failure
    #
    def execute(sql)
      raise(ArgumentError, "Bad SQL parameter") unless sql.kind_of?(String)

      client = ensure_connection
      Pod4.logger.debug(__FILE__){ "execute: #{sql}" }
      client.exec(sql)

    rescue => e
      handle_error(e)
    end

    ##
    # Run SQL code on the server as per execute() but with parameter insertion.
    #
    # Placeholders in the SQL string should all be %s as per sql_helper methods.
    # Values should be as returned by sql_helper methods.
    #
    def executep(sql, *vals)
      raise(ArgumentError, "Bad SQL parameter") unless sql.kind_of?(String)

      client = ensure_connection
      Pod4.logger.debug(__FILE__){ "parameterised execute: #{sql}" }
      client.exec_params( *parse_for_params(sql, vals) )

    rescue => e
      handle_error(e)
    end

    ##
    # Open the connection to the database.
    #
    # This is called from a Connection Object.
    #
    def new_connection(params)
      Pod4.logger.info(__FILE__){ "Connecting to DB" }

      client = PG.connect(params)
      raise DataBaseError, "Bad Connection" unless client.status == PG::CONNECTION_OK

      client

    rescue => e
      handle_error(e)
    end

    ##
    # Close the connection to the database.
    #
    # Pod4 itself doesn't use this(?)
    #
    def close_connection(conn)
      Pod4.logger.info(__FILE__){ "Closing connection to DB" }
      conn.finish unless conn.nil?

    rescue => e
      handle_error(e)
    end

    ##
    # Expose @connection, for testing only.
    #
    def _connection
      @connection
    end

    private

    ##
    # True if we are connected to a database
    #
    def connected?(conn)
      return false if conn.nil?
      return false if conn.status != PG::CONNECTION_OK

      # pg's own examples suggest we poke the database rather than trust
      # @client.status, so...
      conn.exec('select 1;')
      true
    rescue PG::Error
      return false
    end

    ##
    # Return a client from the connection pool and check it is open.
    # Since pg gives us @client.reset to reconnect, we should use it rather than just call open
    #
    def ensure_connection
      client = @connection.client(self)

      if client.nil?
        open
      elsif ! connected?(client)
        client.reset
      end

      client
    end

    def handle_error(err, kaller=nil)
      kaller ||= caller[1..-1]

      Pod4.logger.error(__FILE__){ err.message }

      case err
        when ArgumentError, Pod4::Pod4Error, Pod4::CantContinue
          raise err.class, err.message, kaller

        when PG::Error
          raise Pod4::DatabaseError, err.message, kaller

        else
          raise Pod4::Pod4Error, err.message, kaller
      end

    end

    ##
    # build a hash of column -> oid
    #
    def make_oid_hash(query)

      query.fields.each_with_object({}) do |f,h|
        h[f.to_sym] = query.ftype( query.fnumber(f) )
      end

    end

    ##
    # Cast a query row
    #
    # This is to step around problems with pg type mapping. There is definitely a way to tell pg to
    # cast money and numeric as BigDecimal, but, it's not documented...
    #
    # Also, for the pg_jruby gem, type mapping doesn't work at all?
    #
    def cast_row_fudge(row, oids)
      lFloat  =->(s) { Float(s) rescue s }
      lInt    =->(s) { Integer(s,10) rescue s }
      lTime   =->(s) { Time.parse(s) rescue s }
      lDate   =->(s) { Date.parse(s) rescue s }
      lBigDec =->(s) { BigDecimal(s) rescue s }

      row.each_with_object({}) do |(k,v),h|
        key = k.to_sym
        oid = oids[key]

        h[key] = 
          case
            when v.class != String then v # assume already converted

            when oid == 1700 then lBigDec.(v)        # numeric
            when oid == 790  then lBigDec.(v[1..-1]) # "£1.23"
            when oid == 1082 then lDate.(v)

            when [16, 1560].include?(oid)   then cast_bool(v)
            when [700, 701].include?(oid)   then lFloat.(v)
            when [20, 21, 23].include?(oid) then lInt.(v)
            when [1114, 1184].include?(oid) then lTime.(v)

            else v
          end

      end

    end
    
    ##
    # Given a value from the database which supposedly represents a boolean ... return one.
    # It might of course be NULL/nil; that's allowed, too.
    #
    def cast_bool(val)
      if val.nil?
        nil
      elsif val.is_a? String
        %w|T TRUE|.include?(val.to_s.upcase)
      elsif val.respond_to?(:to_i) # String responds to to_i, remember
        val.to_i == 1
      else
        nil
      end
    end

    def read_or_die(id)
      raise CantContinue, "'No record found with ID '#{id}'" if read(id).empty?
    end

    def parse_for_params(sql, vals)
      new_params = sql.scan("%s").map.with_index{|e,i| "$#{i + 1}" }
      new_vals   = vals.map{|v| v.nil? ? nil : quote(v, nil).to_s }

      [ sql_subst(sql, *new_params), new_vals ]
    end

  end # of PgInterface


end
