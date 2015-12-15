require 'tiny_tds'
require 'octothorpe'

require_relative 'interface'
require_relative 'errors'


module Pod4


  ##
  # Pod4 Interface for requests on a SQL table via TinyTDS.
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

      #---
      # These are set in the class because it keeps the model code cleaner: the
      # definition of the interface stays in the interface, and doesn't leak
      # out into the model.
      #+++

      def set_db(db);        @db     = db.to_s.to_sym;    end
      def set_table(table);  @table  = table.to_s.to_sym; end
      def set_id_fld(idFld); @id_fld = idFld.to_s.to_sym; end
    end
    ##


    ##
    # Initialise the interface by passing it a TinyTDS connection hash.
    # For testing ONLY you can also pass an object which pretends to be a
    # TinyTDS client. 
    #
    def initialize(connectHash, testClient=nil)

      raise Pod4Error, 'no call to set_db in the interface definition' \
        if self.class.db.nil?

      raise Pod4Error, 'no call to set_table in the interface definition' \
        if self.class.table.nil?

      raise Pod4Error, 'no call to set_id_fld in the interface definition' \
        if self.class.id_fld.nil?

      @connect_hash = connectHash
      @test_client  = testClient 
      @db           = nil

      TinyTds::Client.default_query_options[:as] = :hash
      TinyTds::Client.default_query_options[:symbolize_keys] = true

    rescue => e
      handle_error(e)
    end


    ##
    # Selection is whatever Sequel's `where` supports.
    #
    def list(selection=nil)

      if selection
        sel = selection.map {|k,v| "[#{k}] = #{quote v}" }.join(" and ")
        sql = %Q|select * 
                     from [#@table]
                     where #{sel};|

      else
        sql = %Q|select * from [#@table];|
      end

      rows = []
      select(sql) {|r| rows << Octothorpe.new(r) }
      rows

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

      sql = "insert into [#@table]\n"
      sql << "    ( " << ks.join(",") << ")\n"
      sql << "    output inserted.[#@id_fld]\n"
      sql << "    values( " << vs.join(",") << ");"
      x = select(sql)

      x.first #bamf

    rescue => e
      handle_error(e) 
    end


    ##
    # ID corresponds to whatever you set in set_id_fld
    #
    def read(id)
      raise ArgumentError if id.nil?

      sql = %Q|select * 
                   from [#@table] 
                   where [#@table].[#@id_fld] = #{quote id};|

      record = []
      select(sql) {|r| record << Octothorpe.new(r) }

      raise DatabaseError, "'No record found with ID '#{id}'" if rec == []
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

      #read(id) # to check it exists BAMF

      sets = record.map {|k,v| "    [#{k}] = #{quote v}" }

      sql = "update [#@table] set\n"
      sql << sets.join(",") << "\n"
      sql << "where [#@id_fld] = #{quote id};"
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

      #read(id) # to check it exists BAMF
      
      execute( %Q|delete [#@table]
                      where [#@id_fld] = #{quote id};| )

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
    def select(sql)
      $logger.debug(__FILE__){ "select: #{sql}" }

      open unless connected?
      query = @db.execute(sql)

      if block_given?
        query.each {|r| yield r }
        rows = nil
      else
        rows = []
        @db.execute(sql).each {|r| rows << r }
      end

      @db.cancel  #bamf ???
      rows

    rescue => e
      handle_error(e)
    end


    ##
    # Run SQL code on the server; return true or false for success or failure
    #
    def execute(sql)
      $logger.debug(__FILE__){ "execute: #{sql}" }

      open unless connected?
      r = @db.execute(sql)
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
      $logger.info(__FILE__){ "Connecting to DB" }
      tDB = @test_Client || TinyTds::Client.new(@connect_hash)
      raise "Bad Connection" unless tDB.active?

      @db = tDB
      execute("use [#@db]")

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
      $logger.info(__FILE__){ "Closing connection to DB" }
      @db.close unless @db.nil?

    rescue => e
      handle_error(e)
    end


    ##
    # True if we are connected to a database
    #
    def connected?
      @db && @db.active?
    end


    def handle_error(err)
      Pod4.logger.error(__FILE__){ err.message }

      case err

        when ArgumentError, Pod4::Pod4Error
          raise err

        when TimyTDS::Error
          raise Pod4::DatabaseError.from_error(err)

        else
          raise Pod4::Pod4Error.from_error(err)

      end

    end


    def quote(fld)
      fld.kind_of?(String) ? "'#{fld}'" : fld
    end


  end


end
