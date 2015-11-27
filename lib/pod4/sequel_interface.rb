require 'sequel'
require 'octothorpe'

require_relative 'interface'
require_relative 'errors'


module Pod4


  ##
  # Pod4 Interface for a Sequel table.
  #
  # If your DB table is one-one with your model, you shouldn't need to override
  # anything.
  #
  # Example:
  #     class CustomerInterface < SwingShift::SequelInterface
  #       set_table  :customer
  #       set_id_fld :id
  #     end
  #
  class SequelInterface < Interface

    class << self
      attr_reader :table, :id_fld

      #---
      # These are set in the class because it keeps the model code cleaner: the
      # definition of the interface stays in the interface, and doesn't leak
      # out into the model.
      #+++

      def set_table(table);  @table  = table; end
      def set_id_fld(idFld); @id_fld = idFld; end
    end
    ##


    ##
    # Initialise the interface by passing it the Sequel DB object.
    #
    def initialize(db)
      raise ArgumentError unless db.kind_of? Sequel::Database

      raise Pod4Error, 'no call to set_table in the interface definition' \
        if self.class.table.nil?

      raise Pod4Error, 'no call to set_id_fld in the interface definition' \
        if self.class.id_fld.nil?

      @db     = db
      @table  = db[self.class.table]
      @id_fld = self.class.id_fld

    rescue => e
      handle_error(e)
    end


    ##
    # Selection is whatever Sequel's `where` supports.
    #
    def list(selection=nil)
      (selection ? @table.where(selection) : @table.all).map do |x| 
        Octothorpe.new(x) 
      end
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

      @table.insert(record.to_h)

    rescue => e
      handle_error(e) 
    end


    ##
    # ID corresponds to whatever you set in set_id_fld
    #
    def read(id)
      raise ArgumentError if id.nil?

      rec = @table[@id_fld => id]
      raise DatabaseError, "'No record found with ID '#{id}'" if rec.nil?

      Octothorpe.new(rec)

    rescue => e
      handle_error(e)
    end


    ##
    # ID is whatever you set in the interface using set_id_fld
    # record should be a Hash or Octothorpe.
    #
    def update(id, record)
      read(id) # to check it exists
      @table.where(@id_fld => id).update(record.to_h)
      self
    rescue => e
      handle_error(e)
    end


    ##
    # ID is whatever you set in the interface using set_id_fld
    #
    def delete(id)
      read(id) # to check it exists
      @table.where(@id_fld => id).delete
      self
    rescue => e
      handle_error(e)
    end


    ##
    # Bonus method: execute arbitrary SQL. Returns nil.
    #
    def execute(sql)
      raise ArgumentError unless sql.kind_of?(String)
      @db.run(sql)
    rescue => e
      handle_error(e)
    end


    ## 
    # Bonus method: execute arbitrary SQL and return the resulting dataset as a
    # Hash.
    #
    def select(sql)
      raise ArgumentError unless sql.kind_of?(String)
      @db[sql].all
    rescue => e
      handle_error(e)
    end


    protected


    def handle_error(err)

      case err

        when ArgumentError, Pod4::Pod4Error
          raise err

        when Sequel::ValidationFailed
          raise Pod4::ValidationError.from_error(err)

        when Sequel::UniqueConstraintViolation,
             Sequel::ForeignKeyConstraintViolation,
             Sequel::DatabaseError

          raise Pod4::DatabaseError.from_error(err)

        else
          raise Pod4::Pod4Error.from_error(err)

      end

    end


  end


end
