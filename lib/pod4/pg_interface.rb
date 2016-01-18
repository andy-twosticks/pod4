require 'pg'
require 'octothorpe'
require 'date'
require 'time'
require 'bigdecimal'

require_relative 'interface'
require_relative 'errors'


module Pod4


  ##
  # Pod4 Interface for requests on a SQL table via pg, the PostgresQL adapter.
  #
  # If your DB table is one-one with your model, you shouldn't need to override
  # anything.
  #
  # Example:
  #     class CustomerInterface < SwingShift::PgInterface
  #       set_table  :customer
  #       set_id_fld :id
  #     end
  #
  class PgInterface < Interface

    class << self
      attr_reader :table, :id_fld

      #--
      # These are set in the class because it keeps the model code cleaner: the
      # definition of the interface stays in the interface, and doesn't leak
      # out into the model.
      #++

      def set_table(table);  @table  = table.to_s.to_sym; end
      def set_id_fld(idFld); @id_fld = idFld.to_s.to_sym; end
    end
    ##


    ##
    # Initialise the interface by passing it a Pg connection hash.
    # For testing ONLY you can also pass an object which pretends to be a
    # Pg client, in which case the hash is pretty much ignored.
    #
    def initialize(connectHash, testClient=nil)

      raise Pod4Error, 'no call to set_table in the interface definition' \
        if self.class.table.nil?

      raise Pod4Error, 'no call to set_id_fld in the interface definition' \
        if self.class.id_fld.nil?

      raise ArgumentError, 'invalid connection hash' \
        unless connectHash.kind_of?(Hash)

      @connect_hash = connectHash.dup
      @test_client  = testClient 
      @client       = nil

    rescue => e
      handle_error(e)
    end


    def table;  self.class.table;  end
    def id_fld; self.class.id_fld; end


    ##
    # Selection is whatever Sequel's `where` supports.
    #
    def list(selection=nil)

      raise Pod4::DatabaseError, 'selection is not a hash' \
        unless selection.nil? || selection.respond_to?(:keys)

      if selection
        sel = selection.map {|k,v| %Q|"#{k}" = #{quote v}| }.join(" and ")
        sql = %Q|select * 
                     from "#{table}"
                     where #{sel};|

      else
        sql = %Q|select * from "#{table}";|
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

      ks = record.keys.map   {|k| %Q|"#{k}"| }.join(',')
      vs = record.values.map {|v| quote v }.join(',')

      sql = %Q|insert into "#{table}"
                   ( #{ks} )
                   values( #{vs} )
                   returning "#{id_fld}";| 

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
                   from "#{table}" 
                   where "#{id_fld}" = #{quote id};|

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
      sets = record.map {|k,v| %Q|    "#{k}" = #{quote v}| }.join(',')

      sql = %Q|update "#{table}" set
                   #{sets}
                   where "#{id_fld}" = #{quote id};|

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
      execute( %Q|delete from "#{table}" where "#{id_fld}" = #{quote id};| )

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

      ensure_connection

      Pod4.logger.debug(__FILE__){ "select: #{sql}" }

      rows = []
      @client.exec(sql) do |query|
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

      @client.cancel 

      rows

    rescue => e
      handle_error(e)
    end


    ##
    # Run SQL code on the server; return true or false for success or failure
    #
    def execute(sql)
      raise ArgumentError unless sql.kind_of?(String)

      ensure_connection

      Pod4.logger.debug(__FILE__){ "execute: #{sql}" }
      @client.exec(sql)

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
      client = @test_Client || PG.connect(@connect_hash)
      raise "Bad Connection" unless client.status == PG::CONNECTION_OK

      # This gives us type mapping for integers, floats, booleans, and dates
      # -- but annoyingly the PostgreSQL types 'numeric' and 'money' remain as
      # strings... we fudge that elsewhere.
      client.type_map_for_queries = PG::BasicTypeMapForQueries.new(client)
      client.type_map_for_results = PG::BasicTypeMapForResults.new(client)

      @client = client
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
      @client.finish unless @client.nil?

    rescue => e
      handle_error(e)
    end


    ##
    # True if we are connected to a database
    #
    def connected?
      return false if @client.nil?
      return false if @client.status != PG::CONNECTION_OK

      # pg's own examples suggest we poke the database rather than trust
      # @client.status, so...
      @client.exec('select 1;')
      true
    rescue PG::Error
      return false
    end


    ##
    # Since pg gives us @client.reset to reconnect, we should use it rather
    # than just call open
    #
    def ensure_connection

      if @client.nil?
        open
      elsif ! connected?
        @client.reset
      end

    end


    def handle_error(err)
      Pod4.logger.error(__FILE__){ err.message }

      case err

        when ArgumentError, Pod4::Pod4Error
          raise err

        when PG::Error
          raise Pod4::DatabaseError.from_error(err)

        else
          raise Pod4::Pod4Error.from_error(err)

      end

    end


    def quote(fld)

      case fld
        when String, Date, Time
          "'#{fld}'" 
        when BigDecimal
          fld.to_f
        else 
          fld
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
    # This is to step around problems with pg type mapping
    # There is definitely a way to tell pg to cast money and numeric as
    # BigDecimal, but, it's not documented and no one can tell me how to do it!
    #
    def cast_row_fudge(row, oids)

      row.each_with_object({}) do |(k,v),h|
        key = k.to_sym

        h[key] = 
          case
            when v.nil? then nil
            when oids[key] == 1700 then BigDecimal.new(v)        # numeric
            when oids[key] == 790  then BigDecimal.new(v[1..-1]) # "£1.23"
            else v
          end

      end

    end


  end

end
