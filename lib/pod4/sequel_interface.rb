require 'sequel'
require 'octothorpe'

require 'core/lib/interface'


module SwingShift


  ##
  # SwingShift Interface for a Sequel table.
  #
  # If your DB table is one-one with your model, you shouldn;t need to override
  # anything.
  #
  # Example:
  #     class CustomerInterface < SwingShift::SequelInterface
  #       set_table  :customer
  #       set_id_fld :id
  #     end
  #
  class SequelInterface < SwingShift::Interface

    class << self
      attr_reader :table, @id_fld

      # ---
      # These are set in the class because it keeps the model code cleaner: the
      # definition of the interface stays in the interface, and doesn't leak
      # out into the model.
      # +++

      def set_table(table);  @table  = table; end
      def set_id_fld(idFld); @id_fld = idFld; end
    end
    ##


    ##
    # Initialise the interface by passing it the Sequel DB object.
    #
    def initialize(db)
      @db     = db
      @table  = self.class.table
      @id_fld = self.class.id_fld
    end


    ##
    # Selection is a hash of field: value
    #
    def list(selection=nil)
      Octothorpe.new(selection ? @table.where(selection) : @table.all)
    rescue => e
      handle_error(e)
    end


    ##
    # Record is a hash of field: value
    # By a happy coincidence, insert returns the unique ID for the record,
    # which is just what we want to do, too.
    #
    def create(record)
      @table.insert(record.to_h)
    rescue => e
      handle_error(e)
    end


    ##
    # ID corresponds to whatever you set in set_id_fld
    #
    def read(id)
      Octothorpe.new( @table[@id_fld => id] )
    rescue => e
      handle_error(e)
    end


    ##
    # id is whatever you set in the interface using set_id_fld
    # record should be a Hash or Octothorpe.
    #
    def update(id, record)
      @table[@id_fld => id].update(record.to_h)
      self
    rescue => e
      handle_error(e)
    end


    ##
    # id is whatever you set in the interface using set_id_fld
    #
    def delete(id)
      @table[@id_fld => id].delete
      self
    rescue => e
      handle_error(e)
    end


    ##
    # Bonus method: execute arbitrary SQL and return success or failure.
    #
    def execute(sql)
      @db.run(sql)
    rescue => e
      handle_error(e)
    end


    ## 
    # Bonus method: execute arbitrary SQL and return the resulting dataset.
    #
    def select(sql)
      @db[sql].all
    rescue => e
      handle_error(e)
    end


    private


    def handle_error(err)
      case err

        when Sequel::ValidationFailed
          raise SwingShift::ValidationError.from_error(err)

        when Sequel::UniqueConstraintViolation,
             Sequel::ForeignKeyConstraintViolation,
             Sequel::DatabaseError

          raise SwingShift::DatabaseError.from_error(err)

        else
          raise SwingShiftError.from_error(err)

      end


      raise err
    end


  end


end
