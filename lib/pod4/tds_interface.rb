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
  # Pod4 Interface for requests on a SQL table via TinyTds.
  #
  # If your DB table is one-one with your model, you shouldn't need to override anything.
  #
  # Example:
  #     class CustomerInterface < SwingShift::TdsInterface
  #       set_db     :fred
  #       set_table  :customer
  #       set_id_fld :id
  #     end
  #
  # Note: TinyTDS does not appear to support parameterised queries! 
  #
  class TdsInterface < Interface
    include SQLHelper

    attr_reader :id_fld

    class << self
      #--
      # These are set in the class because it keeps the model code cleaner: the definition of the
      # interface stays in the interface, and doesn't leak out into the model.
      #++

      ##
      # Use this to set the database name.
      #
      def set_db(db)
        define_class_method(:db) {db.to_s.to_sym}
      end

      def db 
        raise Pod4Error, "You need to use set_db to set the database name"
      end

      ##
      # Use this to set the schema name (optional)
      #
      def set_schema(schema)
        define_class_method(:schema) {schema.to_s.to_sym}
      end

      def schema; nil; end

      ##
      # Use this to set the name of the table
      #
      def set_table(table)
        define_class_method(:table) {table.to_s.to_sym}
      end

      def table
        raise Pod4Error, "You need to use set_table to set the table name"
      end

      ##
      # This sets the column that holds the unique id for the table
      #
      def set_id_fld(idFld, opts={}) 
        ai = opts.fetch(:autoincrement) { true }
        define_class_method(:id_fld) {idFld.to_s.to_sym}
        define_class_method(:id_ai)  {!!ai}
      end

      def id_fld
        raise Pod4Error, "You need to use set_table to set the table name"
      end

    end # of class << self

    ##
    # Initialise the interface by passing it a TinyTds connection hash OR a ConnectionPool object.
    #
    def initialize(args)
      case args
        when Hash
          @connection = ConnectionPool.new(interface: self.class)
          @connection.data_layer_options = args

        when ConnectionPool
          @connection = args

        else
          raise ArgumentError, "Bad Argument"
      end

      sc = self.class
      raise(Pod4Error, 'no call to set_db in the interface definition')     if sc.db.nil?
      raise(Pod4Error, 'no call to set_table in the interface definition')  if sc.table.nil?
      raise(Pod4Error, 'no call to set_id_fld in the interface definition') if sc.id_fld.nil?

      TinyTds::Client.default_query_options[:as] = :hash
      TinyTds::Client.default_query_options[:symbolize_keys] = true

    rescue => e
      handle_error(e)
    end

    def db;     self.class.db;     end
    def schema; self.class.schema; end
    def table;  self.class.table;  end
    def id_fld; self.class.id_fld; end
    def id_ai ; self.class.id_ai;  end

    def quoted_table
      schema ? %Q|[#{schema}].[#{table}]| : %Q|[#{table}]|
    end

    def quote_field(fld)
      "[#{super(fld, nil)}]"
    end

    ##
    # Selection is a hash or something like it: keys should be field names. We return any records
    # where the given fields equal the given values.
    #
    def list(selection=nil)
      raise(Pod4::DatabaseError, 'selection parameter is not a hash') \
        unless selection.nil? || selection.respond_to?(:keys)

      sql, vals = sql_select(nil, selection)
      select( sql_subst(sql, *vals.map{|v| quote v}) ) {|r| Octothorpe.new(r) }

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

      sql, vals = sql_insert(ot)
      x = select sql_subst(sql, *vals.map{|v| quote v})
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
      rows = select sql_subst(sql, *vals.map{|v| quote v}) 
      Octothorpe.new(rows.first)

    rescue => e
      # select already wrapped any error in a Pod4::DatabaseError, but in this case we want to try
      # to catch something. Ruby 2.0 doesn't define Exception.cause, but if it doesn't, we do in
      # Pod4Error, so. (Side note: TinyTds' error class structure is a bit poor...)
      raise CantContinue, "Problem reading record. Is '#{id}' really an ID?" \
        if e.respond_to?(:cause) \
        && e.cause.class   == TinyTds::Error \
        && e.cause.message =~ /conversion failed/i

      handle_error(e)
    end

    ##
    # ID is whatever you set in the interface using set_id_fld record should be a Hash or
    # Octothorpe.
    #
    def update(id, record)
      raise(ArgumentError, "Bad type for record parameter") \
        unless record.kind_of?(Hash) || record.kind_of?(Octothorpe)

      read_or_die(id)

      sql, vals = sql_update(record, id_fld => id)
      execute sql_subst(sql, *vals.map{|v| quote v})

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
      execute sql_subst(sql, *vals.map{|v| quote v})

      self

    rescue => e
      handle_error(e)
    end

    ##
    # Override the sql_insert method in sql_helper since our SQL is rather different
    #
    def sql_insert(record)
      flds, vals = parse_fldsvalues(record)
      ph = vals.map{|x| placeholder }

      sql = %Q|insert into #{quoted_table}
                 ( #{flds.join ','} )
                 output inserted.#{quote_field id_fld}
                 values( #{ph.join ','} );|

      [sql, vals]
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
      raise(ArgumentError, "Bad sql parameter") unless sql.kind_of?(String)

      client = ensure_connected

      Pod4.logger.debug(__FILE__){ "select: #{sql}" }
      query = client.execute(sql)

      rows = []
      query.each do |r| 

        if block_given? 
          rows << yield(r)
        else
          rows << r
        end

      end

      query.cancel 
      rows

    rescue => e
      handle_error(e)
    end

    ##
    # Run SQL code on the server; return true or false for success or failure
    #
    def execute(sql)
      raise(ArgumentError, "Bad sql parameter") unless sql.kind_of?(String)

      client = ensure_connected

      Pod4.logger.debug(__FILE__){ "execute: #{sql}" }
      r = client.execute(sql)

      r.do
      r

    rescue => e
      handle_error(e)
    end

    ##
    # Wrapper for the data source library escape routine, which is all we can offer in terms of SQL
    # injection protection. (Its not much.)
    #
    def escape(thing)
      client = ensure_connected
      thing.kind_of?(String) ? client.escape(thing) : thing
    end

    ##
    # Open the connection to the database.
    #
    # This is called by ConnectionPool.
    #
    def new_connection(params)
      Pod4.logger.info(__FILE__){ "Connecting to DB" }
      client = TinyTds::Client.new(params)
      raise "Bad Connection" unless client.active?

      client.execute("use [#{self.class.db}]").do

      client

    rescue => e
      handle_error(e)
    end

    ##
    # Close the connection to the database.
    #
    # We don't actually use this.  Theoretically it would be called by ConnectionPool, but we
    # don't.  I've left it in for completeness.
    #
    def close_connection(conn)
      Pod4.logger.info(__FILE__){ "Closing connection to DB" }
      conn.close unless conn.nil?

    rescue => e
      handle_error(e)
    end

    ##
    # Expose @connection for test purposes only
    #
    def _connection
      @connection
    end

    private

    ##
    # Return an open client connection from the Connection Pool, or else raise an error
    #
    def ensure_connected
      client = @connection.client(self)
      
      # If this connection has expired somehow, try to get another one.
      unless connected?(client)
        @connection.drop(self)
        client = @connection.client(self)
      end

      fail "Bad Connection" unless connected?(client)

      client
    end

    ##
    # True if we are connected to a database
    #
    def connected?(conn)
      conn && conn.active?
    end

    def handle_error(err, kaller=nil)
      kaller ||= caller[1..-1]

      Pod4.logger.error(__FILE__){ err.message }

      case err

        when ArgumentError, Pod4::Pod4Error, Pod4::CantContinue
          raise err.class, err.message, kaller

        when TinyTds::Error
          raise Pod4::DatabaseError, err.message, kaller

        else
          raise Pod4::Pod4Error, err.message, kaller

      end

    end

    ##
    # Overrride the quote routine in sql_helper.
    #
    # * TinyTDS doesn't cope with datetime
    #
    # * We might as well use it to escape strings, since that's the best we can do -- although I
    #   suspect that it's just turning ' into '' and nothing else...
    #
    def quote(fld)
      case fld
        when DateTime, Time
          %Q|'#{fld.to_s[0..-7]}'|
        when String, Symbol
          %Q|'#{escape fld.to_s}'|
        else
          super
      end

    end

    def read_or_die(id)
      raise CantContinue, "'No record found with ID '#{id}'" if read(id).empty?
    end

  end # of TdsInterface


end

