require 'pod4/tds_interface'

require_relative 'shared_examples_for_interface'


class TestTdsInterface < TdsInterface
  set_table :customer
  set_id_fld :id
end

class BadInterface1 < TdsInterface
  set_table :customer
end

class BadInterface2 < TdsInterface
  set_id_fld :id
end


describe TestTdsInterface do

  # We actually connect to a special test database for this. I don't generally
  # like unit tests to involve other classes at all, but otherwise we are
  # hardly testing anything, and in any case we do need to test that this class
  # successfully interfaces with Sequel. We can't really do that without
  # talking to a database.

  let(:data) do
    [ {name: 'Barney', price: 1.11},
      {name: 'Fred',   price: 2.22},
      {name: 'Betty',  price: 3.33} ]
  end

  def fill_data(ifce)
    data.each{|r| ifce.create(r) }
  end

  # This is stolen almost verbatim from the Sequel Readme. We use an in-memory
  # sqlite database, and we assume that Sequel is sane and behaves broadly the
  # same for our limited purposes as it would when talking to TinyTDS or Pg.
  # This may be an entirely unwarranted assumption. If so, we will have to
  # change this. But in any case, we are not in the business of testing Sequel:
  # just our interface to it.
  let (:db) do
    db = Sequel.sqlite
    db.create_table :customer do
      primary_key :id
      String      :name
      Float       :price
    end
    db
  end

  let(:interface) { TestSequelInterface.new(db) }

  before do
    fill_data(interface)
  end

  ##


  it_behaves_like 'an interface' do

    let(:interface) do
      db = Sequel.sqlite
      db.create_table :customer do
        primary_key :id
        String      :name
        Float       :price
      end

      TestSequelInterface.new(db)
    end

    let(:record)    { {name: 'Barney', price: 1.11} }
    let(:record_id) { 'Barney' }

  end
  ##


  describe 'SequelInterface.set_table' do
    it 'takes one argument' do
      expect( SequelInterface ).to respond_to(:set_table).with(1).argument
    end
  end
  ##


  describe 'SequelInterface.table' do
    it 'returns the table' do
      expect( TestSequelInterface.table ).to eq :customer
    end
  end
  ##


  describe 'SequelInterface.set_id_fld' do
    it 'takes one argument' do
      expect( SequelInterface ).to respond_to(:set_id_fld).with(1).argument
    end
  end
  ##


  describe 'SequelInterface.id_fld' do
    it 'returns the ID field name' do
      expect( TestSequelInterface.id_fld ).to eq :id
    end
  end
  ##


  describe '#new' do

    it 'requires a Sequel DB object' do
      expect{ TestSequelInterface.new        }.to raise_exception ArgumentError
      expect{ TestSequelInterface.new(nil)   }.to raise_exception ArgumentError
      expect{ TestSequelInterface.new('foo') }.to raise_exception ArgumentError

      expect{ TestSequelInterface.new(db) }.not_to raise_exception
    end

    it 'requires the table and id field to be defined in the class' do
      expect{ SequelInterface.new(db) }.to raise_exception Pod4Error
      expect{ BadInterface1.new(db)   }.to raise_exception Pod4Error
      expect{ BadInterface2.new(db)   }.to raise_exception Pod4Error
    end

  end
  ##


  describe '#create' do

    let(:hash) { {name: 'Bam-Bam', price: 4.44} }
    let(:ot)   { Octothorpe.new(name: 'Wilma', price: 5.55) }

    it 'raises a Pod4::DatabaseError if anything goes wrong' do
      expect{ interface.create(one: 'two') }.to raise_exception DatabaseError
    end

    it 'creates the record when given a hash' do
      # kinda impossible to seperate these two tests
      id = interface.create(hash)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include hash
    end

    it 'creates the record when given an Octothorpe' do
      id = interface.create(ot)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include ot.to_h
    end

  end
  ##


  describe '#read' do

    it 'returns the record for the id as an Octothorpe' do
      expect( interface.read(2).to_h ).to include(name: 'Fred', price: 2.22)
    end

    it 'raises a Pod4::DatabaseError if anything goes wrong' do
      expect{ interface.read(:foo) }.to raise_exception DatabaseError
      expect{ interface.read(99)   }.to raise_exception DatabaseError
    end

  end
  ##



  describe '#list' do

    it 'has an optional selection parameter, a hash' do
      # Actually it does not have to be a hash, but FTTB we only support that.
      expect{ interface.list(name: 'Barney') }.not_to raise_exception
    end

    it 'returns an array of Octothorpes that match the records' do
      # convert each OT to a hash and remove the ID key
      arr = interface.list.map {|ot| x = ot.to_h; x.delete(:id); x }

      expect( arr ).to match_array data
    end

    it 'returns a subset of records based on the selection parameter' do
      expect( interface.list(name: 'Fred').size ).to eq 1

      expect( interface.list(name: 'Betty').first.to_h ).
        to include(name: 'Betty', price: 3.33)

    end

    it 'returns an empty Array if nothing matches' do
      expect( interface.list(name: 'Yogi') ).to eq([])
    end

    it 'raises DatabaseError if the selection criteria is nonsensical' do
      expect{ interface.list('foo') }.to raise_exception Pod4::DatabaseError
    end

  end
  ##
  

  describe '#update' do

    let(:id) { interface.list.first[:id] }

    it 'updates the record at ID with record parameter' do
      record = {name: 'Booboo', price: 99.99}
      interface.update(id, record)

      expect( interface.read(id).to_h ).to include(record)
    end

    it 'raises a DatabaseError if anything weird happens' do
      expect{ interface.update(id, smarts: 'more') }.
        to raise_exception DatabaseError

      expect{ interface.update(99, name: 'Booboo') }.
        to raise_exception DatabaseError

    end

  end
  ##


  describe '#delete' do
    it 'raises DatabaseError if anything hinky happens' do
      expect{ interface.delete(:foo) }.to raise_exception DatabaseError
      expect{ interface.delete(99)   }.to raise_exception DatabaseError
    end
  end
  ##


  describe '#execute' do

    let(:sql) { 'delete from customer where price < 2.0;' }

    it 'requires an SQL string' do
      expect{ interface.execute      }.to raise_exception ArgumentError
      expect{ interface.execute(nil) }.to raise_exception ArgumentError
      expect{ interface.execute(14)  }.to raise_exception ArgumentError
    end

    it 'raises some sort of Pod4 error if it runs into problems' do
      expect{ interface.execute('delete from not_a_table') }.
        to raise_exception Pod4Error

    end

    it 'executes the string' do
      expect{ interface.execute(sql) }.not_to raise_exception
      expect( interface.list.size ).to eq(data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include 'Barney'
    end

  end
  ##


  describe '#select' do

    it 'requires an SQL string' do
      expect{ interface.select      }.to raise_exception ArgumentError
      expect{ interface.select(nil) }.to raise_exception ArgumentError
      expect{ interface.select(14)  }.to raise_exception ArgumentError
    end

    it 'raises some sort of Pod4 error if it runs into problems' do
      expect{ interface.select('select * from not_a_table') }.
        to raise_exception Pod4Error

    end

    it 'returns the result of the sql' do
      sql1 = 'select name from customer where price < 2.0;'
      sql2 = 'select name from customer where price < 0.0;'

      expect{ interface.select(sql1) }.not_to raise_exception
      expect( interface.select(sql1) ).to eq( [{name: 'Barney'}] )
      expect( interface.select(sql2) ).to eq( [] )
    end

    it 'works if you pass a non-select' do
      # By which I mean: still executes the SQL; returns []
      sql = 'delete from customer where price < 2.0;'
      ret = interface.select(sql)

      expect( interface.list.size ).to eq(data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include 'Barney'
      expect( ret ).to eq( [] )
    end


  end
  ##


end

