require 'octothorpe'

require_relative 'interface'
require_relative 'errors'


module Pod4


  ##
  # Pod4 Interface *for testing*. Fakes a table and records.
  #
  # Example:
  #     class TestModel < Pod4::Model
  #       attr_columns :one, :two
  #       set_interface NullInterface.new( :one, :two [ {one: 1, two: 2} ] )
  #       ...
  #
  # The first column passed is taken to be the ID.
  # Note that ID is not auto-assigned; you need to specify it in the record.
  #
  class NullInterface < Interface

    ##
    # Initialise the interface by passing it a list of columns and an array of
    # hashes to fill them.
    #
    def initialize(*cols, data)
      raise ArgumentError if cols.nil? || cols == []

      @cols   = cols.dup.map(&:to_sym)
      @data   = Array.new(data.dup).flatten 
      @id_fld = @cols.first

    rescue => e
      handle_error(e)
    end


    ##
    # Selection is a hash, but only the first key/value pair is honoured.
    #
    def list(selection=nil)
      if selection
        key, value = selection.to_a.first
        rows = @data.find_all {|r| r[key.to_sym] == value}
      else
        rows = @data
      end

      rows.map{|x| Octothorpe.new(x) }

    rescue => e
      handle_error(e)
    end


    ##
    # Record is a hash of field: value
    # Note that we will store any old crap, not just the fields you named in
    # new().
    #
    def create(record)
      raise ArgumentError if record.nil? || ! record.respond_to?(:to_h)
      @data << record.to_h
      record[@id_fld]

    rescue => e
      handle_error(e) 
    end


    ##
    # ID is the first column you named in new()
    #
    def read(id)
      raise ArgumentError if id.nil?

      rec = @data.find{|x| x[@id_fld] == id }
      raise DatabaseError, "'No record found with ID '#{id}'" if rec.nil?

      Octothorpe.new(rec)

    rescue => e
      handle_error(e)
    end


    ##
    # ID is the first column you named in new()
    # record should be a Hash or Octothorpe.
    # Again, note that we don't care what columns you send us.
    #
    def update(id, record)
      raise ArgumentError if id.nil?

      rec = @data.find{|x| x[@id_fld] == id }
      raise Pod4::Pod4Error if rec.nil?

      rec.merge!(record.to_h)
      self
    rescue => e
      handle_error(e)
    end


    ##
    # ID is that first column
    #
    def delete(id)
      raise ArgumentError if id.nil?
      read(id) # to see if it exists
      @data.delete_if {|r| r[@id_fld] == id }
      self
    rescue => e
      handle_error(e)
    end


    protected


    def handle_error(err)

      case err
        when ArgumentError, Pod4::Pod4Error
          raise err
        else
          raise Pod4::Pod4Error.from_error(err)
      end

    end


  end


end