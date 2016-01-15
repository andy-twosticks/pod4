require 'tiny_tds'
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
  # If your DB table is one-one with your model, you shouldn't need to override
  # anything.
  #
  # Example:
  #     class CustomerInterface < SwingShift::TdsInterface
  #       set_db     :fred
  #       set_table  :customer
  #       set_id_fld :id
  #     end
  #
  class TdsInterface < Interface

    class << self
      attr_reader :db, :table, :id_fld

      #--
      # These are set in the class because it keeps the model code cleaner: the
      # definition of the interface stays in the interface, and doesn't leak
      # out into the model.
      #++

      def set_db(db);        @db     = db.to_s.to_sym;    end
      def set_table(table);  @table  = table.to_s.to_sym; end
      def set_id_fld(idFld); @id_fld = idFld.to_s.to_sym; end
    end
    ##


    ##
    # Initialise the interface by passing it a TinyTds connection hash.
    # For testing ONLY you can also pass an object which pretends to be a
    # TinyTds client, in which case the hash is pretty much ignored.
    #
    def initialize(connectHash, testClient=nil)

      raise Pod4Error, 'no call to set_db in the interface definition' \
        if self.class.db.nil?

      raise Pod4Error, 'no call to set_table in the interface definition' \
        if self.class.table.nil?

      raise Pod4Error, 'no call to set_id_fld in the interface definition' \
        if self.class.id_fld.nil?

      raise ArgumentError, 'invalid connection hash' \
        unless connectHash.kind_of?(Hash)

      @connect_hash = connectHash.dup
      @test_client  = testClient 
      @client       = nil

      TinyTds::Client.default_query_options[:as] = :hash
      TinyTds::Client.default_query_options[:symbolize_keys] = true

    rescue => e
      handle_error(e)
    end


    def db;     self.class.db;     end
    def table;  self.class.table;  end
    def id_fld; self.class.id_fld; end


    ##
    # Selection is whatever Sequel's `where` supports.
    #
    def list(selection=nil)

      raise Pod4::DatabaseError, 'selection is not a hash' \
        unless selection.nil? || selection.respond_to?(:keys)

      if selection
        sel = selection.map {|k,v| "[#{k}] = #{quote v}" }.join(" and ")
        sql = %Q|select * 
                     from [#{table}]
                     where #{sel};|

      else
        sql = %Q|select * from [#{table}];|
      end

      select(sql) {|r| Octothorpe.new(r) }

    rescue => e
      handle_error(e)
    end


    ##
    # Record is a hash of field: value
    # By a happy coincidence, insert returns the unique ID for the record,
    # which is just what we want to do, too.
    #
    def create(record)
      raise ArgumentError unless record.kind_of?(Hash) \
                              || record.kind_of?(Octothorpe)

      ks = record.keys.map   {|k| "[#{k}]" }
      vs = record.values.map {|v| quote v } 

      sql = "insert into [#{table}]\n"
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
      raise ArgumentError if id.nil?

      sql = %Q|select * 
                   from [#{table}] 
                   where [#{id_fld}] = #{quote id};|

      record = select(sql) {|r| Octothorpe.new(r) }

      raise DatabaseError, "'No record found with ID '#{id}'" if record == []
      record.first

    rescue => e
      handle_error(e)
    end


    ##
    # ID is whatever you set in the interface using set_id_fld
    # record should be a Hash or Octothorpe.
    #
    def update(id, record)
      raise ArgumentError unless record.kind_of?(Hash) \
                              || record.kind_of?(Octothorpe)

      read(id) # to raise Pod4::DatabaseError if id does not exist

      sets = record.map {|k,v| "    [#{k}] = #{quote v}" }

      sql = "update [#{table}] set\n"
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
      raise ArgumentError if id.nil?

      read(id) # to raise Pod4::DatabaseError if id does not exist
      execute( %Q|delete [#{table}] where [#{id_fld}] = #{quote id};| )

      self

    rescue => e
      handle_error(e)
    end


    ##
    # Run SQL code on the server. Return the results.
    #
    # Will return an array of records, or you can use it in block mode, like
    # this:
    #
    #     select("select * from customer") do |r|
    #       # r is a single record
    #     end
    #
    # The returned results will be an array of hashes (or if you passed a
    # block, of whatever you returned from the block).
    #
    def select(sql)
      raise ArgumentError unless sql.kind_of?(String)

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
      raise ArgumentError unless sql.kind_of?(String)

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
    # We don't actually use this, but it's here for completeness. Maybe a
    # caller will find it useful.
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


    def handle_error(err)
      Pod4.logger.error(__FILE__){ err.message }

      case err

        when ArgumentError, Pod4::Pod4Error
          raise err

        when TinyTds::Error
          raise Pod4::DatabaseError.from_error(err)

        else
          raise Pod4::Pod4Error.from_error(err)

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
        else 
          fld
      end

    end


  end


end
