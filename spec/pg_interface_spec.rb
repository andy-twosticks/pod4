require 'pod4/pg_interface'

require_relative 'shared_examples_for_interface'
require_relative 'fixtures/database'


class TestPgInterface < PgInterface
  set_table :customer
  set_id_fld :id
end

class BadPgInterface1 < PgInterface
  set_table :customer
end

class BadPgInterface2 < PgInterface
  set_id_fld :id
end


describe TestPgInterface do

  def db_setup(connect)
    client = PG.connect(connect)

    client.exec(%Q|drop table if exists customer;|)

    client.exec(%Q|
      create table customer ( 
        id    serial,
        name  text,
        price numeric );| )

  ensure
    client.finish if client
  end


  def fill_data(ifce)
    @data.each{|r| ifce.create(r) }
  end


  before(:all) do
    @connect_hash = DB[:pg]
    db_setup(@connect_hash)

    @data = [ {name: 'Barney', price: 1.11},
              {name: 'Fred',   price: 2.22},
              {name: 'Betty',  price: 3.33} ]

  end


  before do
    # TRUNCATE TABLE also resets the identity counter
    interface.execute(%Q|truncate table customer;|)
  end


  let(:interface) do
    TestPgInterface.new(@connect_hash)
  end

  #####


  it_behaves_like 'an interface' do

    let(:interface) do
      TestPgInterface.new(@connect_hash)
    end

    let(:record) { {name: 'Barney', price: 1.11} }

  end
  ##
 

=begin

  describe 'PgInterface.set_db' do
    it 'takes one argument' do
      expect( PgInterface ).to respond_to(:set_db).with(1).argument
    end
  end
  ##


  describe 'PgInterface.db' do
    it 'returns the table' do
      expect( TestPgInterface.db ).to eq :pod4_test
    end
  end
  ##


  describe 'PgInterface.set_table' do
    it 'takes one argument' do
      expect( PgInterface ).to respond_to(:set_table).with(1).argument
    end
  end
  ##


  describe 'PgInterface.table' do
    it 'returns the table' do
      expect( TestPgInterface.table ).to eq :customer
    end
  end
  ##


  describe 'PgInterface.set_id_fld' do
    it 'takes one argument' do
      expect( PgInterface ).to respond_to(:set_id_fld).with(1).argument
    end
  end
  ##


  describe 'PgInterface.id_fld' do
    it 'returns the ID field name' do
      expect( TestPgInterface.id_fld ).to eq :id
    end
  end
  ##


  describe '#new' do

    it 'requires a TinyTds connection string' do
      expect{ TestPgInterface.new        }.to raise_exception ArgumentError
      expect{ TestPgInterface.new(nil)   }.to raise_exception ArgumentError
      expect{ TestPgInterface.new('foo') }.to raise_exception ArgumentError

      expect{ TestPgInterface.new(@connect_hash) }.not_to raise_exception
    end

    it 'requires the table and id field to be defined in the class' do
      expect{ PgInterface.new(@connect_hash) }.to raise_exception Pod4Error

      expect{ BadPgInterface1.new(@connect_hash) }.
        to raise_exception Pod4Error

      expect{ BadPgInterface2.new(@connect_hash) }.
        to raise_exception Pod4Error

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
    before { fill_data(interface) }

    it 'returns the record for the id as an Octothorpe' do
      expect( interface.read(2).to_h ).to include(@data[1])
    end

    it 'raises a Pod4::DatabaseError if anything goes wrong' do
      expect{ interface.read(:foo) }.to raise_exception DatabaseError
      expect{ interface.read(99)   }.to raise_exception DatabaseError
    end

  end
  ##



  describe '#list' do
    before { fill_data(interface) }

    it 'has an optional selection parameter, a hash' do
      # Actually it does not have to be a hash, but FTTB we only support that.
      expect{ interface.list(name: 'Barney') }.not_to raise_exception
    end

    it 'returns an array of Octothorpes that match the records' do
      # convert each OT to a hash and remove the ID key
      arr = interface.list.map {|ot| x = ot.to_h; x.delete(:id); x }

      expect( arr ).to match_array @data
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
    before { fill_data(interface) }

    let(:id) { interface.list.first[:id] }

    def float_price(row)
      row[:price] = row[:price].to_f
      row
    end

    it 'updates the record at ID with record parameter' do
      record = {name: 'Booboo', price: 99.99}
      interface.update(id, record)

      # It so happens that TinyTds returns money as BigDecimal --
      # this is a really good thing, even though it screws with our test.
      expect( float_price( interface.read(id).to_h ) ).to include(record)
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

    def list_contains(id)
      interface.list.find {|x| x[interface.id_fld] == id }
    end

    let(:id) { interface.list.first[:id] }

    before { fill_data(interface) }

    it 'raises DatabaseError if anything hinky happens' do
      expect{ interface.delete(:foo) }.to raise_exception DatabaseError
      expect{ interface.delete(99)   }.to raise_exception DatabaseError
    end

    it 'makes the record at ID go away' do
      expect( list_contains(id) ).to be_truthy
      interface.delete(id)
      expect( list_contains(id) ).to be_falsy
    end

  end
  ##


  describe '#execute' do

    let(:sql) { 'delete from customer where price < 2.0;' }

    before { fill_data(interface) }

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
      expect( interface.list.size ).to eq(@data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include 'Barney'
    end

  end
  ##


  describe '#select' do

    before { fill_data(interface) }

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

      expect( interface.list.size ).to eq(@data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include 'Barney'
      expect( ret ).to eq( [] )
    end


  end
  ##

=end

end

