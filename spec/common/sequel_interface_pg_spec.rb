#
# Supplemental test for Sequel -- tests using PG gem in MRI, jeremyevans-postgres-pg under jruby?
#

require 'pod4/sequel_interface'

require 'sequel'
require 'date'
require 'time'
require 'bigdecimal'


class TestSequelInterfacePg < SequelInterface
  set_table :customer
  set_id_fld :id
end

class SchemaSequelInterfacePg < SequelInterface
  set_schema :public
  set_table  :customer
  set_id_fld :id
end

class ProdSequelInterfacePg < SequelInterface
  set_table  :product
  set_id_fld :code
end




describe TestSequelInterfacePg do

  let(:data) do
    d = []
    d << { name:      'Barney',
           level:     1.23,
           day:       Date.parse("2016-01-01"),
           timestamp: Time.parse('2015-01-01 12:11'),
           qty:       BigDecimal.new("1.24"),
           price:     BigDecimal.new("1.24") }

    d << { name:      'Fred',
           level:     2.34,
           day:       Date.parse("2016-02-02"),
           timestamp: Time.parse('2015-01-02 12:22'),
           qty:       BigDecimal.new("2.35"),
           price:     BigDecimal.new("2.35") }

    d << { name:      'Betty',
           level:     3.45,
           day:       Date.parse("2016-03-03"),
           timestamp: Time.parse('2015-01-03 12:33'),
           qty:       BigDecimal.new("3.46"),
           price:     BigDecimal.new("3.46") }

    d
  end

  def fill_data(ifce)
    data.each{|r| ifce.create(r) }
  end

  def fill_product_data(ifce)
    ifce.create( {code: "foo", name: "bar"} )
  end


  let (:db) do
    db = Sequel.connect('postgres://pod4test:pod4test@centos7andy/pod4_test?search_path=public')

    db.run %Q|
      drop table if exists customer;
      drop table if exists product;

      create table customer (
        id        serial primary key,
        name      text,
        level     real      null,
        day       date      null,
        timestamp timestamp null,
        price     money     null,
        qty       numeric   null );
    
      create table product (
        code text,
        name text );|

    db
  end

  let(:interface)      { TestSequelInterfacePg.new(db) }
  let(:prod_interface) { ProdSequelInterfacePg.new(db) }


  before do
    interface.execute %Q|
      truncate table customer restart identity;
      truncate table product;|

    fill_data(interface)
  end

  after do
    db.disconnect
  end

  ##


  describe '#quoted_table' do

    it 'returns just the table when the schema is not set' do
      expect( interface.quoted_table.downcase ).to eq( %Q|"customer"| )
    end

    it 'returns the schema plus table when the schema is set' do
      ifce = SchemaSequelInterfacePg.new(db)
      expect( ifce.quoted_table.downcase ).to eq( %|"public"."customer"| )
    end

  end
  ##


  describe '#create' do

    let(:hash) { {name: 'Bam-Bam', qty: 4.44} }
    let(:ot)   { Octothorpe.new(name: 'Wilma', qty: 5.55) }

    it 'raises a Pod4::DatabaseError if anything goes wrong' do
      expect{ interface.create(one: 'two') }.to raise_exception DatabaseError
    end

    it 'creates the record when given a hash' do
      # kinda impossible to seperate these two tests
      id = interface.create(hash)

      expect( id ).not_to be_nil
      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include hash
    end

    it 'creates the record when given an Octothorpe' do
      id = interface.create(ot)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include ot.to_h
    end

    it 'does not freak out if the hash has symbol values' do
      # Which, Sequel does
      expect{ interface.create(name: :Booboo) }.not_to raise_exception
    end

    it 'shouldnt have a problem with record values of nil' do
      record = {name: 'Ranger', price: nil}
      expect{ interface.create(record) }.not_to raise_exception
      id = interface.create(record)
      expect( interface.read(id).to_h ).to include(record)
    end

    it 'shouldnt have a problem with strings containing special characters' do
      record = {name: "T'Challa[]", price: nil}
      expect{ interface.create(record) }.not_to raise_exception
      id = interface.create(record)
      expect( interface.read(id).to_h ).to include(record)
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

    it 'returns the record for the id as an Octothorpe' do
      expect( interface.read(2).to_h ).to include(name: 'Fred', qty: 2.35)
    end

    it 'raises a Pod4::CantContinue if the ID is bad' do
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
      expect( level ).to be_within(0.001).of( data.first[:level] )
    end

    it 'returns date fields as Date' do
      date = interface.read(1).>>.day

      expect( date ).to be_a_kind_of Date
      expect( date ).to eq data.first[:day]
    end

    it 'returns datetime fields as Time' do
      timestamp = interface.read(1).>>.timestamp

      expect( timestamp ).to be_a_kind_of Time
      expect( timestamp ).to eq data.first[:timestamp]
    end

    it 'returns numeric fields as BigDecimal' do
      qty = interface.read(1).>>.qty

      expect( qty ).to be_a_kind_of BigDecimal
      expect( qty ).to eq data.first[:qty]
    end

    it 'returns money fields as bigdecimal' do
      pending "Sequel/PG returns a string for Money type"

      price = interface.read(1).>>.price

      expect( price ).to be_a_kind_of BigDecimal
      expect( price ).to eq data.first[:price]
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

    it 'returns an array of Octothorpes that match the records' do
      arr = interface.list.map {|ot| x = ot.to_h}

      expect( arr.size ).to eq(data.size)

      data.each do |d|
        r = arr.find{|x| x[:name] == d[:name] }
        expect( r ).not_to be_nil
        expect( r[:level]     ).to be_within(0.001).of( d[:level] )
        expect( r[:day]       ).to eq d[:day]
        expect( r[:timestamp] ).to eq d[:timestamp]
        expect( r[:qty]       ).to eq d[:qty]
      end
 
    end

    it 'returns a subset of records based on the selection parameter' do
      expect( interface.list(name: 'Fred').size ).to eq 1

      expect( interface.list(name: 'Betty').first.to_h ).
        to include(name: 'Betty', qty: 3.46)

    end

    it 'returns an empty Array if nothing matches' do
      expect( interface.list(name: 'Yogi') ).to eq([])
    end

    it 'raises DatabaseError if the selection criteria is nonsensical' do
      expect{ interface.list('foo') }.to raise_exception Pod4::DatabaseError
    end

    it 'returns an empty array if there is no data' do
      interface.list.each {|x| interface.delete(x[interface.id_fld]) }
      expect( interface.list ).to eq([])
    end

    it 'does not freak out if the hash has symbol values' do
      # Which, Sequel does
      expect{ interface.list(name: :Barney) }.not_to raise_exception
    end


  end
  ##
  

  describe '#update' do

    let(:id) { interface.list.first[:id] }

    it 'updates the record at ID with record parameter' do
      record = {name: 'Booboo', qty: 99.99}
      interface.update(id, record)

      booboo = interface.read(id)
      expect( booboo.>>.name       ).to eq( record[:name] )
      expect( booboo.>>.qty.to_f ).to eq( record[:qty] )
    end

    it 'raises a CantContinue if anything weird happens with the ID' do
      expect{ interface.update(99, name: 'Booboo') }.
        to raise_exception CantContinue

    end

    it 'raises a DatabaseError if anything weird happensi with the record' do
      expect{ interface.update(id, smarts: 'more') }.
        to raise_exception DatabaseError

    end

    it 'does not freak out if the hash has symbol values' do
      # Which, Sequel does
      expect{ interface.update(id, name: :Booboo) }.not_to raise_exception
    end

    it 'shouldn\'t have a problem with record values of nil' do
      record = {name: 'Ranger', qty: nil}
      expect{ interface.update(id, record) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include(record)
    end

    it 'shouldn\'t have a problem with strings containing special characters' do
      record = {name: "T'Challa[]", qty: nil}
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

    let(:sql) { 'delete from customer where qty < 2.0;' }

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
      sql1 = 'select name from customer where qty < 2.0;'
      sql2 = 'select name from customer where qty < 0.0;'

      expect{ interface.select(sql1) }.not_to raise_exception
      expect( interface.select(sql1) ).to eq( [{name: 'Barney'}] )
      expect( interface.select(sql2) ).to eq( [] )
    end

    it 'works if you pass a non-select' do
      # By which I mean: still executes the SQL; returns []
      sql = 'delete from customer where qty < 2.0;'
      ret = interface.select(sql)

      expect( interface.list.size ).to eq(data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include 'Barney'
      expect( ret ).to eq( [] )
    end

  end
  ##


  describe "#executep" do
    # For the time being lets assume that Sequel does its job and the three modes we are calling
    # actually work

    let(:sql) { 'delete from customer where qty < ?;' }

    it 'requires an SQL string and a mode' do
      expect{ interface.executep                 }.to raise_exception ArgumentError
      expect{ interface.executep(nil)            }.to raise_exception ArgumentError
      expect{ interface.executep(14, :update)    }.to raise_exception ArgumentError
      expect{ interface.executep(14, :update, 2) }.to raise_exception ArgumentError
    end

    it 'requires the mode to be valid' do
      expect{ interface.executep(sql, :foo, 2) }.to raise_exception ArgumentError
    end

    it 'raises some sort of Pod4 error if it runs into problems' do
      expect{ interface.executep('delete from not_a_table where thingy = ?', :delete, 14) }.
        to raise_exception Pod4Error

    end

    it 'executes the string' do
      expect{ interface.executep(sql, :delete, 2.0) }.not_to raise_exception
      expect( interface.list.size ).to eq(data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include 'Barney'
    end

  end


  describe "#selectp" do

    it 'requires an SQL string' do
      expect{ interface.selectp      }.to raise_exception ArgumentError
      expect{ interface.selectp(nil) }.to raise_exception ArgumentError
      expect{ interface.selectp(14)  }.to raise_exception ArgumentError
    end

    it 'raises some sort of Pod4 error if it runs into problems' do
      expect{ interface.selectp('select * from not_a_table where thingy = ?', 14) }.
        to raise_exception Pod4Error

    end

    it 'returns the result of the sql' do
      sql = 'select name from customer where qty < ?;'

      expect{ interface.selectp(sql, 2.0) }.not_to raise_exception
      expect( interface.selectp(sql, 2.0) ).to eq( [{name: 'Barney'}] )
      expect( interface.selectp(sql, 0.0) ).to eq( [] )
    end

    it 'works if you pass a non-select' do
      # By which I mean: still executes the SQL; returns []
      sql = 'delete from customer where qty < ?;'
      ret = interface.selectp(sql, 2.0)

      expect( interface.list.size ).to eq(data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include 'Barney'
      expect( ret ).to eq( [] )
    end

  end


end

