require 'octothorpe'
require 'date'
require 'time'
require 'bigdecimal'

require_relative 'interface'
require_relative 'errors'


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
  class TdsInterface < Interface

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
      def set_id_fld(idFld) 
        define_class_method(:id_fld) {idFld.to_s.to_sym}
      end

      def id_fld
        raise Pod4Error, "You need to use set_table to set the table name"
      end

    end
    ##


    ##
    # Initialise the interface by passing it a TinyTds connection hash.# For testing ONLY you can
    # also pass an object which pretends to be a TinyTds client, in which case the hash is pretty
    # much ignored.
    #
    def initialize(connectHash, testClient=nil)
      raise(Pod4Error, 'no call to set_db in the interface definition') if self.class.db.nil?
      raise(Pod4Error, 'no call to set_table in the interface definition') if self.class.table.nil?
      raise(Pod4Error, 'no call to set_id_fld in the interface definition') if self.class.id_fld.nil?
      raise(ArgumentError, 'invalid connection hash') unless connectHash.kind_of?(Hash)

      @connect_hash = connectHash.dup
      @test_client  = testClient 
      @client       = nil

      TinyTds::Client.default_query_options[:as] = :hash
      TinyTds::Client.default_query_options[:symbolize_keys] = true

    rescue => e
      handle_error(e)
    end


    def db;     self.class.db;     end
    def schema; self.class.schema; end
    def table;  self.class.table;  end
    def id_fld; self.class.id_fld; end

    def quoted_table
      schema ? %Q|[#{schema}].[#{table}]| : %Q|[#{table}]|
    end


    ##
    # Selection is a hash or something like it: keys should be field names. We return any records
    # where the given fields equal the given values.
    #
    def list(selection=nil)

      raise(Pod4::DatabaseError, 'selection parameter is not a hash') \
        unless selection.nil? || selection.respond_to?(:keys)

      if selection
        sel = selection.map {|k,v| "[#{k}] = #{quote v}" }.join(" and ")
        sql = %Q|select * 
                     from #{quoted_table}
                     where #{sel};|

      else
        sql = %Q|select * from #{quoted_table};|
      end

      select(sql) {|r| Octothorpe.new(r) }

    rescue => e
      handle_error(e)
    end


    ##
    # Record is a hash of field: value
    #
    # By a happy coincidence, insert returns the unique ID for the record, which is just what we
      # want to do, too.
    #
    def create(record)
      raise(ArgumentError, "Bad type for record parameter") \
            unless record.kind_of?(Hash) || record.kind_of?(Octothorpe)

      ks = record.keys.map   {|k| "[#{k}]" }
      vs = record.values.map {|v| quote v } 

      sql = "insert into #{quoted_table}\n"
      sql << "    ( " << ks.join(",") << ")\n"
      sql << "    output inserted.[#{id_fld}]\n"
      sql << "    values( " << vs.join(",") << ");"

      x = select(sql)
      x.first[id_fld]

    rescue => e
      handle_error(e) 
    end


    ##
    # ID corresponds to whatever you set in set_id_fld
    #
    def read(id)
      raise(ArgumentError, "ID parameter is nil") if id.nil?

      sql = %Q|select * 
                   from #{quoted_table} 
                   where [#{id_fld}] = #{quote id};|

      Octothorpe.new( select(sql).first )

    rescue => e
      # select already wrapped any error in a Pod4::DatabaseError, but in this case we want to try
      # to catch something. (Side note: TinyTds' error class structure is a bit poor...)
      raise CantContinue, "Problem reading record. Is '#{id}' really an ID?" \
        if e.cause.class   == TinyTds::Error \
        && e.cause.message =~ /invalid column/i

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

      sets = record.map {|k,v| "    [#{k}] = #{quote v}" }

      sql = "update #{quoted_table} set\n"
      sql << sets.join(",") << "\n"
      sql << "where [#{id_fld}] = #{quote id};"
      execute(sql)

      self

    rescue => e
      handle_error(e)
    end


    ##
    # ID is whatever you set in the interface using set_id_fld
    #
    def delete(id)
      read_or_die(id)
      execute( %Q|delete #{quoted_table} where [#{id_fld}] = #{quote id};| )

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
      raise(ArgumentError, "Bad sql parameter") unless sql.kind_of?(String)

      open unless connected?

      Pod4.logger.debug(__FILE__){ "select: #{sql}" }
      query = @client.execute(sql)

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

      open unless connected?

      Pod4.logger.debug(__FILE__){ "execute: #{sql}" }
      r = @client.execute(sql)

      r.do
      r

    rescue => e
      handle_error(e)
    end


    protected


    ##
    # Open the connection to the database.
    #
    # No parameters are needed: the option hash has everything we need.
    #
    def open
      Pod4.logger.info(__FILE__){ "Connecting to DB" }
      client = @test_Client || TinyTds::Client.new(@connect_hash)
      raise "Bad Connection" unless client.active?

      @client = client
      execute("use [#{self.class.db}]")

      self

    rescue => e
      handle_error(e)
    end


    ##
    # Close the connection to the database.
    #
    # We don't actually use this, but it's here for completeness. Maybe a caller will find it
    # useful.
    #
    def close
      Pod4.logger.info(__FILE__){ "Closing connection to DB" }
      @client.close unless @client.nil?

    rescue => e
      handle_error(e)
    end


    ##
    # True if we are connected to a database
    #
    def connected?
      @client && @client.active?
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


    def quote(fld)

      case fld
        when DateTime, Time
          %Q|'#{fld.to_s[0..-7]}'|
        when String, Date
          %Q|'#{fld}'|
        when BigDecimal
          fld.to_f
        when nil
          'NULL'
        else 
          fld
      end

    end


    def read_or_die(id)
      raise CantContinue, "'No record found with ID '#{id}'" if read(id).empty?
    end

  end


end

