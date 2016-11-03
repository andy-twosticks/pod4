require 'octothorpe'
require 'date'
require 'time'
require 'bigdecimal'

require_relative 'interface'
require_relative 'errors'
require_relative 'sql_helper'


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
  #       set_id_fld :id
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
      def set_id_fld(idFld)
        define_class_method(:id_fld) {idFld.to_s.to_sym}
      end

      def id_fld
        raise Pod4Error, "You need to use set_id_fld to set the ID column"
      end

    end
    ##


    ##
    # Initialise the interface by passing it a Pg connection hash. For testing ONLY you can also
    # pass an object which pretends to be a Pg client, in which case the hash is pretty much
    # ignored.
    #
    def initialize(connectHash, testClient=nil)
      raise(ArgumentError, 'invalid connection hash') unless connectHash.kind_of?(Hash)

      @connect_hash = connectHash.dup
      @test_client  = testClient 
      @client       = nil

    rescue => e
      handle_error(e)
    end


    def schema; self.class.schema; end
    def table;  self.class.table;  end
    def id_fld; self.class.id_fld; end


    ##
    # Selection is whatever Sequel's `where` supports.
    #
    def list(selection=nil)
      raise(ArgumentError, 'selection parameter is not a hash') \
        unless selection.nil? || selection.respond_to?(:keys)

=begin
      if selection
        sel = selection.map {|k,v| %Q|"#{k}" = #{quote v}| }.join(" and ")
        sql = %Q|select * 
                     from #{quoted_table}
                     where #{sel};|

      else
        sql = %Q|select * from #{quoted_table};|
      end
=end

      sql  = sql_select(nil, selection)
      vals = selection ? selection.values.map{|v| quote v} : nil

      select( sql_subst(sql, vals) ) {|r| Octothorpe.new(r) }

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

=begin
      ks = record.keys.map   {|k| %Q|"#{k}"| }.join(',')
      vs = record.values.map {|v| quote v }.join(',')

      sql = %Q|insert into #{quoted_table}
                   ( #{ks} )
                   values( #{vs} )
                   returning "#{id_fld}";| 
=end

      sql  = sql_insert(id_fld, record) 
      vals = record.values.map{|v| quote v}

      x = select( sql_subst(sql, vals) )
      x.first[id_fld]

    rescue => e
      handle_error(e)
    end


    ##
    # ID corresponds to whatever you set in set_id_fld
    #
    def read(id)
      raise(ArgumentError, "ID parameter is nil") if id.nil?

=begin
      sql = %Q|select * 
                   from #{quoted_table} 
                   where "#{id_fld}" = #{quote id};|
=end

      sql  = sql_select(nil, id_fld => id) % quote(id)
      rows = select( sql_subst(sql, quote(id)) )
      Octothorpe.new(rows.first)

    rescue => e
      # Select has already wrapped the error in a Pod4Error, but in this case we want to catch
      # something
      raise CantContinue, "That doesn't look like an ID" \
        if e.cause.class == PG::InvalidTextRepresentation

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

=begin
      sets = record.map {|k,v| %Q| "#{k}" = #{quote v}| }.join(',')
      sql = %Q|update #{quoted_table} set
                   #{sets}
                   where "#{id_fld}" = #{quote id};|
=end

      sql = sql_update(record, id_fld => id)
      execute( sql_subst(sql, quote(id)) )

      self

    rescue => e
      handle_error(e)
    end


    ##
    # ID is whatever you set in the interface using set_id_fld
    #
    def delete(id)
      read_or_die(id)

=begin
      execute( %Q|delete from #{quoted_table} where "#{id_fld}" = #{quote id};| )
=end

      sql = sql_delete(id_fld => id)
      execute( sql_subst(sql, quote(id)) )

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
      raise(ArgumentError, "Bad SQL parameter") unless sql.kind_of?(String)

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
      raise DataBaseError, "Bad Connection" \
        unless client.status == PG::CONNECTION_OK

      # This gives us type mapping for integers, floats, booleans, and dates -- but annoyingly the
      # PostgreSQL types 'numeric' and 'money' remain as strings... we fudge that elsewhere.
      #
      # NOTE we now deal with ALL mapping elsewhere, since pg_jruby does not support type mapping.
      # Also: no annoying error messages, and it seems to be a hell of a lot faster now...
      # 
      #     if defined?(PG::BasicTypeMapForQueries)
      #       client.type_map_for_queries = PG::BasicTypeMapForQueries.new(client)
      #     end
      #
      #     if defined?(PG::BasicTypeMapForResults)
      #       client.type_map_for_results = PG::BasicTypeMapForResults.new(client)
      #     end

      @client = client
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
    # Since pg gives us @client.reset to reconnect, we should use it rather than just call open
    #
    def ensure_connection

      if @client.nil?
        open
      elsif ! connected?
        @client.reset
      end

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


    def quote(fld)

      case fld
        when Date, Time
          "'#{fld}'" 
        when String
          "'#{fld.gsub("'", "''")}'" 
        when Symbol
          "'#{fld.to_s.gsub("'", "''")}'" 
        when BigDecimal
          fld.to_f
        when nil
          'NULL'
        else 
          fld
      end

    end
    

    private


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
    # This is to step around problems with pg type mapping There is definitely a way to tell pg to
    # cast money and numeric as BigDecimal, but, it's not documented...
    #
    # Also, for the pg_jruby gem, type mapping doesn't work at all?
    #
    def cast_row_fudge(row, oids)
      lBool   =->(s) { s.to_i = 1 || s.upcase == 'TRUE' }
      lFloat  =->(s) { Float(s) rescue s }
      lInt    =->(s) { Integer(s,10) rescue s }
      lTime   =->(s) { Time.parse(s) rescue s }
      lDate   =->(s) { Date.parse(s) rescue s }
      lBigDec =->(s) { BigDecimal.new(s) rescue s }

      row.each_with_object({}) do |(k,v),h|
        key = k.to_sym
        oid = oids[key]

        h[key] = 
          case
            when v.class != String then v # assume already converted

            when oid == 1700 then lBigDec.(v)        # numeric
            when oid == 790  then lBigDec.(v[1..-1]) # "£1.23"
            when oid == 1082 then lDate.(v)

            when [16, 1560].include?(oid)   then lBool.(v)
            when [700, 701].include?(oid)   then lFloat.(v)
            when [20, 21, 23].include?(oid) then lInt.(v)
            when [1114, 1184].include?(oid) then lTime.(v)

            else v
          end

      end

    end


    def read_or_die(id)
      raise CantContinue, "'No record found with ID '#{id}'" if read(id).empty?
    end

  end


end
