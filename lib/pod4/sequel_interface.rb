require 'octothorpe'

require_relative 'interface'
require_relative 'errors'


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
      def set_id_fld(idFld)
        define_class_method(:id_fld) {idFld.to_s.to_sym}
      end

      def id_fld
        raise Pod4Error, "You need to use set_id_fld to set the ID column name"
      end

    end
    ##


    ##
    # Initialise the interface by passing it the Sequel DB object.
    #
    def initialize(db)
      raise(ArgumentError, "Bad database") unless db.kind_of? Sequel::Database
      raise(Pod4Error, 'no call to set_table in the interface definition') if self.class.table.nil?
      raise(Pod4Error, 'no call to set_id_fld in the interface definition') if self.class.id_fld.nil?

      @db     = db # referemce to the db object
      @table  = db[schema ? "#{schema}__#{table}".to_sym : table]
      @id_fld = self.class.id_fld

    rescue => e
      handle_error(e)
    end


    def schema; self.class.schema; end
    def table;  self.class.table;  end
    def id_fld; self.class.id_fld; end

    def quoted_table
      if schema 
        %Q|#{@db.quote_identifier schema}.#{@db.quote_identifier table}|
      else
        @db.quote_identifier(table)
      end
    end



    ##
    # Selection is whatever Sequel's `where` supports.
    #
    def list(selection=nil)
      sel = sanitise_hash(selection)
      Pod4.logger.debug(__FILE__) { "Listing #{self.class.table}: #{sel.inspect}" }

      (sel ? @table.where(sel) : @table.all).map {|x| Octothorpe.new(x) }
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

      Pod4.logger.debug(__FILE__) { "Creating #{self.class.table}: #{record.inspect}" }

      @table.insert( sanitise_hash(record.to_h) )

    rescue => e
      handle_error(e) 
    end


    ##
    # ID corresponds to whatever you set in set_id_fld
    #
    def read(id)
      raise(ArgumentError, "ID parameter is nil") if id.nil?
      Pod4.logger.debug(__FILE__) { "Reading #{self.class.table} where #{@id_fld}=#{id}" }

      Octothorpe.new( @table[@id_fld => id] )

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

      @table.where(@id_fld => id).update( sanitise_hash(record.to_h) )
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

      @table.where(@id_fld => id).delete
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
      @db.run(sql)
    rescue => e
      handle_error(e)
    end


    ## 
    # Bonus method: execute arbitrary SQL and return the resulting dataset as a Hash.
    #
    def select(sql)
      raise(ArgumentError, "Bad sql parameter") unless sql.kind_of?(String)

      Pod4.logger.debug(__FILE__) { "Select SQL: #{sql}" }
      @db[sql].all
    rescue => e
      handle_error(e)
    end


    protected


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

        else 
          sel

      end

    end


    private


    def read_or_die(id)
      raise CantContinue, "'No record found with ID '#{id}'" if read(id).empty?
    end

  end


end

