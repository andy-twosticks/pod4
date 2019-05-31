require "octothorpe"

require_relative "interface"
require_relative "errors"


module Pod4


  ##
  # Pod4 Interface *for testing*. Fakes a table and records.
  #
  # Example:
  #     class TestModel < Pod4::Model
  #       attr_columns :one, :two
  #       set_interface NullInterface.new( :one, :two [ {one: 1, two: 2},
  #                                                     {one: 2, two: 4} ] )
  #       ...
  #
  # The first column passed is taken to be the ID.  We default to autoincrement = true, as
  # standard.  Note that ID values for the initial data are not auto-assigned; you need to specify them.
  #
  # You can switch to autoincrement = false by setting `interface.id_ai = false`.
  #
  # Note: this is quite different from the behaviour before v1.0, where NullInterface effectively
  # only allowed you to create a non-autoincrement interface.
  #
  class NullInterface < Interface

    attr_reader   :id_fld
    attr_accessor :id_ai

    ##
    # Initialise the interface by passing it a list of columns and an array of hashes to fill them.
    #
    def initialize(*cols, data)
      raise ArgumentError, "no columns"  if cols.nil? || cols == []

      @cols   = cols.dup.map(&:to_sym)
      @data   = Array.new(data.dup).flatten 
      @id_fld = @cols.first
      @id_ai  = true

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
    #
    # Note that we will store any old crap, not just the fields you named in new().
    #
    def create(record)
      raise(ArgumentError, "Create requires an ID") if record.nil? || ! record.respond_to?(:to_h)

      raise(ArgumentError, "Record missing ID field") \
        if !@id_ai && record[@id_fld].nil? && record[@id_fld.to_s].nil?

      datum = record.to_h
      datum[@id_fld] = (@data.size + 1) if @id_ai
      @data << record.to_h

      datum[@id_fld]

    rescue => e
      handle_error(e)
    end

    ##
    # ID is the first column you named in new()
    #
    def read(id)
      raise(ArgumentError, "Read requires an ID") if id.nil?

      rec = @data.find{|x| x[@id_fld] == id }
      Octothorpe.new(rec)

    rescue => e
      handle_error(e)
    end

    ##
    # ID is the first column you named in new(). Record should be a Hash or Octothorpe.
    # Again, note that we don't care what columns you send us.
    #
    def update(id, record)
      raise(ArgumentError, "Update requires an ID") if id.nil?

      rec = @data.find{|x| x[@id_fld] == id }
      raise Pod4::CantContinue, "No record found with ID '#{id}'" unless rec

      rec.merge!(record.to_h)
      self
    rescue => e
      handle_error(e)
    end

    ##
    # ID is that first column
    #
    def delete(id)
      raise(ArgumentError, "Delete requires an ID")  if id.nil?
      raise(Pod4::CantContinue, "'No record found with ID '#{id}'") if read(id).empty?

      @data.delete_if {|r| r[@id_fld] == id }
      self
    rescue => e
      handle_error(e)
    end

    private

    def handle_error(err, kaller=nil)
      kaller ||= caller[1..-1]

      Pod4.logger.error(__FILE__){ err.message }

      case err
        when ArgumentError, Pod4Error, Pod4::CantContinue
          raise err.class, err.message, kaller
        else
          raise Pod4::Pod4Error, err.message, kaller
      end

    end


  end


end

