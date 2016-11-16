require 'pod4/tds_interface'

require 'tiny_tds'
require 'date'

require_relative '../common/shared_examples_for_interface'
require_relative '../fixtures/database'


class TestTdsInterface < TdsInterface
  set_db     :pod4_test
  set_table  :customer
  set_id_fld :id
end

class SchemaTdsInterface < TdsInterface
  set_db     :pod4_test
  set_schema :public
  set_table  :customer
  set_id_fld :id
end

class BadTdsInterface1 < TdsInterface
  set_db :pod4_test
  set_table :customer
end

class BadTdsInterface2 < TdsInterface
  set_db :pod4_test
  set_id_fld :id
end

class ProdTdsInterface < TdsInterface
  set_db     :pod4_test
  set_table  :product
  set_id_fld :code
end


describe TestTdsInterface do

  def db_setup(connect)
    client = TinyTds::Client.new(connect)
    client.execute(%Q|use [pod4_test];|).do

    # Our SQL Server does not support DROP TABLE IF EXISTS !
    # This is apparently an SQL-agnostic way of doing it:
    client.execute(%Q|
      if exists (select * from INFORMATION_SCHEMA.TABLES 
                     where TABLE_NAME   = 'customer' 
                       and TABLE_SCHEMA = 'dbo' )
            drop table dbo.customer;

      if exists (select * from INFORMATION_SCHEMA.TABLES 
                     where TABLE_NAME   = 'product' 
                       and TABLE_SCHEMA = 'dbo' )
            drop table dbo.product;

      create table dbo.customer ( 
        id        int identity(1,1) not null,
        name      nvarchar(max),
        level     real         null,
        day       date         null,
        timestamp datetime     null,
        price     money        null,
        qty       numeric(5,2) null );

      create table dbo.product (
        code nvarchar(20),
        name nvarchar(max) );| ).do

  ensure
    client.close if client
  end


  def fill_data(ifce)
    @data.each{|r| ifce.create(r) }
  end

  def fill_product_data(ifce)
    ifce.create( {code: "foo", name: "bar"} )
  end


  before(:all) do
    @connect_hash = DB[:tds]
    db_setup(@connect_hash)

    @data = []
    @data << { name:      'Barney', 
               level:     1.23, 
               day:       Date.parse("2016-01-01"),
               timestamp: Time.parse('2015-01-01 12:11'),
               price:     BigDecimal.new("1.24"), 
               qty:       BigDecimal.new("1.25") }

    @data << { name:      'Fred', 
               level:     2.34, 
               day:       Date.parse("2016-02-02"),
               timestamp: Time.parse('2015-01-02 12:22'),
               price:     BigDecimal.new("2.35"), 
               qty:       BigDecimal.new("2.36") }

    @data << { name:      'Betty', 
               level:     3.45, 
               day:       Date.parse("2016-03-03"),
               timestamp: Time.parse('2015-01-03 12:33'),
               price:     BigDecimal.new("3.46"), 
               qty:       BigDecimal.new("3.47") }

  end


  before do
    # TRUNCATE TABLE also resets the identity counter
    interface.execute(%Q|truncate table customer;|)
  end


  let(:interface) do
    TestTdsInterface.new(@connect_hash)
  end

  let(:prod_interface) do
    ProdTdsInterface.new(@connect_hash)
  end

  #####


  it_behaves_like 'an interface' do

    let(:interface) do
      TestTdsInterface.new(@connect_hash)
    end


    let(:record) { {name: 'Barney'} }

  end
  ##
 

  describe 'TdsInterface.set_db' do
    it 'takes one argument' do
      expect( TdsInterface ).to respond_to(:set_db).with(1).argument
    end
  end
  ##


  describe 'TdsInterface.db' do
    it 'returns the table' do
      expect( TestTdsInterface.db ).to eq :pod4_test
    end
  end
  ##


  describe 'TdsInterface.set_schema' do
    it 'takes one argument' do
      expect( TdsInterface ).to respond_to(:set_schema).with(1).argument
    end
  end
  ##


  describe 'TdsInterface.schema' do
    it 'returns the schema' do
      expect( SchemaTdsInterface.schema ).to eq :public
    end

    it 'is optional' do
      expect{ TestTdsInterface.schema }.not_to raise_exception
      expect( TestTdsInterface.schema ).to eq nil
    end
  end
  ##


  describe 'TdsInterface.set_table' do
    it 'takes one argument' do
      expect( TdsInterface ).to respond_to(:set_table).with(1).argument
    end
  end
  ##


  describe 'TdsInterface.table' do
    it 'returns the table' do
      expect( TestTdsInterface.table ).to eq :customer
    end
  end
  ##


  describe 'TdsInterface.set_id_fld' do
    it 'takes one argument' do
      expect( TdsInterface ).to respond_to(:set_id_fld).with(1).argument
    end
  end
  ##


  describe 'TdsInterface.id_fld' do
    it 'returns the ID field name' do
      expect( TestTdsInterface.id_fld ).to eq :id
    end
  end
  ##


  describe '#new' do

    it 'requires a TinyTds connection string' do
      expect{ TestTdsInterface.new        }.to raise_exception ArgumentError
      expect{ TestTdsInterface.new(nil)   }.to raise_exception ArgumentError
      expect{ TestTdsInterface.new('foo') }.to raise_exception ArgumentError

      expect{ TestTdsInterface.new(@connect_hash) }.not_to raise_exception
    end

    it 'requires the table and id field to be defined in the class' do
      expect{ TdsInterface.new(@connect_hash) }.to raise_exception Pod4Error

      expect{ BadTdsInterface1.new(@connect_hash) }.
        to raise_exception Pod4Error

      expect{ BadTdsInterface2.new(@connect_hash) }.
        to raise_exception Pod4Error

    end

  end
  ##


  describe '#quoted_table' do

    it 'returns just the table when the schema is not set' do
      expect( interface.quoted_table ).to eq( %Q|[customer]| )
    end

    it 'returns the schema plus table when the schema is set' do
      ifce = SchemaTdsInterface.new(@connect_hash)
      expect( ifce.quoted_table ).to eq( %|[public].[customer]| )
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

    it 'shouldn\'t have a problem with record values of nil' do
      hash2 = {name: 'Ranger', price: nil}
      expect{ interface.create(hash2) }.not_to raise_exception
      id = interface.create(hash2)
      expect( interface.read(id).to_h ).to include(hash2)
    end

    it 'shouldn\'t have a problem with strings containing special characters' do
      hash2 = {name: "T'Challa[]", price: nil}
      expect{ interface.create(hash2) }.not_to raise_exception
      id = interface.create(hash2)
      expect( interface.read(id).to_h ).to include(hash2)
    end

    it 'shouldn\'t have a problem with non-integer keys' do
      hash = {code: "foo", name: "bar"}
      id = prod_interface.create( Octothorpe.new(hash) )

      expect( id ).to eq "foo"
      expect{ prod_interface.read("foo") }.not_to raise_exception
      expect( prod_interface.read("foo").to_h ).to include hash
    end

  end
  ##


  describe '#read' do
    before { fill_data(interface) }

    it 'returns the record for the id as an Octothorpe' do
      rec = interface.read(2)
      expect( rec ).to be_a_kind_of Octothorpe
      expect( rec.>>.name ).to eq 'Fred'
    end

    it 'raises a Pod4::CantContinue if anything goes wrong with the ID' do
      expect{ interface.read(:foo) }.to raise_exception CantContinue
    end

    it 'returns an empty Octothorpe if no record matches the ID' do
      expect{ interface.read(99) }.not_to raise_exception
      expect( interface.read(99) ).to be_a_kind_of Octothorpe
      expect( interface.read(99) ).to be_empty
    end

    it 'returns real fields as Float' do
      level = interface.read(1).>>.level

      expect( level ).to be_a_kind_of Float
      expect( level ).to be_within(0.001).of( @data.first[:level] )
    end

    it 'returns date fields as Date' do
      pending "not supported by TinyTds ¬_¬ "
      date = interface.read(1).>>.day

      expect( date ).to be_a_kind_of Date
      expect( date ).to eq @data.first[:day]
    end

    it 'returns datetime fields as Time' do
      timestamp = interface.read(1).>>.timestamp

      expect( timestamp ).to be_a_kind_of Time
      expect( timestamp ).to eq @data.first[:timestamp]
    end

    it 'returns numeric fields as BigDecimal' do
      qty = interface.read(1).>>.qty

      expect( qty ).to be_a_kind_of BigDecimal
      expect( qty ).to eq @data.first[:qty]
    end

    it 'returns money fields as BigDecimal' do
      price   = interface.read(1).>>.price

      expect( price ).to be_a_kind_of BigDecimal
      expect( price ).to eq @data.first[:price]
    end

    it 'shouldn\'t have a problem with non-integer keys' do
      # this is a 100% overlap with the create test above...
      fill_product_data(prod_interface)

      expect{ prod_interface.read("foo") }.not_to raise_exception
      expect( prod_interface.read("foo").to_h ).to include(code: "foo", name: "bar")
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
      list = interface.list

      expect( list.first ).to be_a_kind_of Octothorpe
      expect( list.map{|x| x.>>.name} ).to match_array @data.map{|y| y[:name]}
    end

    it 'returns a subset of records based on the selection parameter' do
      expect( interface.list(name: 'Fred').size ).to eq 1

      expect( interface.list(name: 'Betty').first.to_h ).
        to include(name: 'Betty', price: 3.46)

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

    it 'raises a CantContinue if anything weird happens with the ID' do
      expect{ interface.update(99, name: 'Booboo') }.
        to raise_exception CantContinue

    end

    it 'raises a DatabaseError if anything weird happens with the record' do
      expect{ interface.update(id, smarts: 'more') }.
        to raise_exception DatabaseError

    end

    it 'shouldn\'t have a problem with record values of nil' do
      record = {name: 'Ranger', price: nil}
      expect{ interface.update(id, record) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include(record)
    end

    it 'shouldn\'t have a problem with strings containing special characters' do
      record = {name: "T'Challa[]", price: nil}
      expect{ interface.update(id, record) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include(record)
    end

    it 'shouldn\'t have a problem with non-integer keys' do
      fill_product_data(prod_interface)
      expect{ prod_interface.update("foo", name: "baz") }.not_to raise_error
      expect( prod_interface.read("foo").to_h[:name] ).to eq "baz"
    end

  end
  ##


  describe '#delete' do

    def list_contains(ifce, id)
      ifce.list.find {|x| x[ifce.id_fld] == id }
    end

    let(:id) { interface.list.first[:id] }

    before { fill_data(interface) }

    it 'raises CantContinue if anything hinky happens with the ID' do
      expect{ interface.delete(:foo) }.to raise_exception CantContinue
      expect{ interface.delete(99)   }.to raise_exception CantContinue
    end

    it 'makes the record at ID go away' do
      expect( list_contains(interface, id) ).to be_truthy
      interface.delete(id)
      expect( list_contains(interface, id) ).to be_falsy
    end

    it 'shouldn\'t have a problem with non-integer keys' do
      fill_product_data(prod_interface)
      expect( list_contains(prod_interface, "foo") ).to be_truthy
      prod_interface.delete("foo")
      expect( list_contains(prod_interface, "foo") ).to be_falsy
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


  describe "#escape" do
    # This just wraps the TinyTDS escape method, and we don't really know what that does.
    # But at the very least it should deal with ' inside a string.
    # Frankly? I suspect that that's all it does.

    it "returns a simple String unchanged" do
      expect( interface.escape "foo" ).to eq %Q|foo|
    end

    it "turns a single quote into a doubled single quote" do
      expect( interface.escape "G'Kar" ).to eq %Q|G''Kar|
    end

  end
  ##

  
end

