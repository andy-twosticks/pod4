require "pod4/pg_interface"
require "pg"

require_relative "../common/shared_examples_for_interface"
require_relative "../fixtures/database"


describe "PgInterface" do

  def db_setup(connect)
    client = PG.connect(connect)

    client.exec(%Q|
      drop table if exists customer;
      drop table if exists product;

      create table customer ( 
        id        serial primary key,
        name      text,
        level     real      null,
        day       date      null,
        timestamp timestamp null,
        price     money     null,
        flag      boolean   null,
        qty       numeric   null );

      create table product (
        code text,
        name text );| )

  ensure
    client.finish if client
  end

  def fill_data(ifce)
    @data.each{|r| ifce.create(r) }
  end

  def fill_product_data(ifce)
    ifce.create( {code: "foo", name: "bar"} )
  end

  def list_contains(ifce, id)
    ifce.list.find {|x| x[ifce.id_fld] == id }
  end

  def float_price(row)
    row[:price] = row[:price].to_f
    row
  end

  let(:pg_interface_class) do
    Class.new PgInterface do
      set_table :customer
      set_id_fld :id
    end
  end

  let(:schema_interface_class) do
    Class.new PgInterface do
      set_schema :public
      set_table  :customer
      set_id_fld :id, autoincrement: true
    end
  end

  let(:prod_interface_class) do
    Class.new PgInterface do
      set_table  :product
      set_id_fld :code, autoincrement: false
    end
  end

  let(:bad_interface_class1) do
    Class.new PgInterface do
      set_table :customer
    end
  end

  let(:bad_interface_class2) do
    Class.new PgInterface do
      set_id_fld :id
    end
  end

  let(:interface) do
    pg_interface_class.new(@pool)
  end

  let(:prod_interface) do
    prod_interface_class.new(@pool)
  end

  before(:all) do
    @connect_hash = DB[:pg]
    db_setup(@connect_hash)

    @data = []
    @data << { name:      "Barney",
               level:     1.23,
               day:       Date.parse("2016-01-01"),
               timestamp: Time.parse("2015-01-01 12:11"),
               price:     BigDecimal("1.24"),
               flag:      true,
               qty:       BigDecimal("1.25") }

    @data << { name:      "Fred",
               level:     2.34,
               day:       Date.parse("2016-02-02"),
               timestamp: Time.parse("2015-01-02 12:22"),
               price:     BigDecimal("2.35"),
               flag:      false,
               qty:       BigDecimal("2.36") }

    @data << { name:      "Betty",
               level:     3.45,
               day:       Date.parse("2016-03-03"),
               timestamp: Time.parse("2015-01-03 12:33"),
               price:     BigDecimal("3.46"),
               flag:      nil,
               qty:       BigDecimal("3.47") }

    # one connection pool for the whole suite, so it doesn't grab (number of tests) connections.
    @pool = ConnectionPool.new(interface: PgInterface)
    @pool.data_layer_options = @connect_hash
  end

  before(:each) do
    interface.execute(%Q|
      truncate table customer restart identity;
      truncate table product;|)

  end


  it_behaves_like "an interface" do
    let(:interface) do
      pg_interface_class.new(@connect_hash)
    end

    let(:record) { {name: "Barney"} }

  end # of it_behaves_like
 

  describe "PgInterface.set_schema" do

    it "takes one argument" do
      expect( pg_interface_class ).to respond_to(:set_schema).with(1).argument
    end

  end # of PgInterface.set_schema


  describe "PgInterface.schema" do

    it "returns the schema" do
      expect( schema_interface_class.schema ).to eq :public
    end

    it "is optional" do
      expect{ pg_interface_class.schema }.not_to raise_exception
      expect( pg_interface_class.schema ).to eq nil
    end

  end # of PgInterface.schema


  describe "PgInterface.set_table" do

    it "takes one argument" do
      expect( pg_interface_class ).to respond_to(:set_table).with(1).argument
    end

  end # of PgInterface.set_table
  

  describe "PgInterface.table" do

    it "returns the table" do
      expect( pg_interface_class.table ).to eq :customer
    end

  end # of PgInterface.table


  describe "PgInterface.set_id_fld" do

    it "takes one argument" do
      expect( pg_interface_class ).to respond_to(:set_id_fld).with(1).argument
    end

    it "takes an optional second 'autoincrement' argument" do
      expect{ PgInterface.set_id_fld(:foo, autoincrement: false) }.not_to raise_error
    end

  end # of PgInterface.set_id_fld


  describe "PgInterface.id_fld" do

    it "returns the ID field name" do
      expect( pg_interface_class.id_fld ).to eq :id
    end

  end # of PgInterface.id_fld


  describe "PgInterface.id_ai" do
     
    it "returns true if autoincrement is true" do
      expect( schema_interface_class.id_ai ).to eq true
    end

    it "returns false if autoincrement is false" do
      expect( prod_interface_class.id_ai ).to eq false
    end

    it "returns true if autoincrement is not specified" do
      expect( pg_interface_class.id_ai ).to eq true
    end
    
  end # of PgInterface.id_ai


  describe "#new" do

    it "creates a ConnectionPool when passed a PG connection hash" do
      ifce = pg_interface_class.new(@connect_hash)
      expect( ifce._connection ).to be_a ConnectionPool
    end
    
    it "uses the ConnectionPool when given one" do
      pool = ConnectionPool.new(interface: pg_interface_class)
      ifce = pg_interface_class.new(pool)

      expect( ifce._connection ).to eq pool
    end

    it "raises ArgumentError when passed something else" do
      expect{ pg_interface_class.new        }.to raise_exception ArgumentError
      expect{ pg_interface_class.new(nil)   }.to raise_exception ArgumentError
      expect{ pg_interface_class.new("foo") }.to raise_exception ArgumentError
    end

  end # of #new
  

  describe "#quoted_table" do

    it "returns just the table when the schema is not set" do
      expect( interface.quoted_table ).to eq( %Q|"customer"| )
    end

    it "returns the schema plus table when the schema is set" do
      ifce = schema_interface_class.new(@connect_hash)
      expect( ifce.quoted_table ).to eq( %|"public"."customer"| )
    end

  end # of #quoted_table


  describe "#create" do
    let(:hash) { {name: "Bam-Bam", price: 4.44} }
    let(:ot)   { Octothorpe.new(name: "Wilma", price: 5.55) }

    it "raises a Pod4::DatabaseError if anything goes wrong" do
      expect{ interface.create(one: "two") }.to raise_exception DatabaseError
    end

    it "raises an ArgumentError if ID field is missing in hash and not AI" do
      hash = {name: "bar"}
      expect{ prod_interface.create(Octothorpe.new hash) }.to raise_error ArgumentError
    end

    it "creates the record when given a hash" do
      # kinda impossible to seperate these two tests
      id = interface.create(hash)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include hash
    end

    it "creates the record when given an Octothorpe" do
      id = interface.create(ot)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include ot.to_h
    end

    it "has no problem with record values of nil" do
      record = {name: "Ranger", price: nil}
      expect{ interface.create(record) }.not_to raise_exception
      id = interface.create(record)
      expect( interface.read(id).to_h ).to include(record)
    end

    it "has no problem with strings containing special characters" do
      record = {name: %Q|T"Challa""|, price: nil}
      expect{ interface.create(record) }.not_to raise_exception
      id = interface.create(record)
      expect( interface.read(id).to_h ).to include(record)
    end

    it "has no problem with non-integer keys" do
      hash = {code: "foo", name: "bar"}
      id = prod_interface.create( Octothorpe.new(hash) )

      expect( id ).to eq "foo"
      expect{ prod_interface.read("foo") }.not_to raise_exception
      expect( prod_interface.read("foo").to_h ).to include hash
    end

    it "calls ConnectionPool#client" do
      expect( interface._connection ).to receive(:client).at_least(:once).and_call_original
      interface.create(ot)
    end

  end # of #create


  describe "#read" do
    before { fill_data(interface) }

    it "returns the record for the id as an Octothorpe" do
      rec = interface.read(2)
      expect( rec ).to be_a_kind_of Octothorpe
      expect( rec.>>.name ).to eq "Fred"
    end

    it "raises a Pod4::CantContinue if the ID is bad" do
      expect{ interface.read(:foo) }.to raise_exception CantContinue
    end

    it "returns an empty Octothorpe if no record matches the ID" do
      expect{ interface.read(99) }.not_to raise_exception
      expect( interface.read(99) ).to be_a_kind_of Octothorpe
      expect( interface.read(99) ).to be_empty
    end

    it "returns real fields as Float" do
      level = interface.read(1).>>.level

      expect( level ).to be_a_kind_of Float
      expect( level ).to be_within(0.001).of( @data.first[:level] )
    end

    it "returns date fields as Date" do
      date = interface.read(1).>>.day

      expect( date ).to be_a_kind_of Date
      expect( date ).to eq @data.first[:day]
    end

    it "returns datetime fields as Time" do
      timestamp = interface.read(1).>>.timestamp

      expect( timestamp ).to be_a_kind_of Time
      expect( timestamp ).to eq @data.first[:timestamp]
    end

    it "returns numeric fields as BigDecimal" do
      qty = interface.read(1).>>.qty

      expect( qty ).to be_a_kind_of BigDecimal
      expect( qty ).to eq @data.first[:qty]
    end

    it "returns money fields as BigDecimal" do
      price   = interface.read(1).>>.price

      expect( price ).to be_a_kind_of BigDecimal
      expect( price ).to eq @data.first[:price]
    end

    it "returns boolean fields as boolean" do
      [1,2,3].each do |i|
        flag = interface.read(i).>>.flag
        expect( [true, false, nil].include? flag ).to be true
        expect( flag ).to be @data[i - 1][:flag]
      end
    end

    it "has no problem with non-integer keys" do
      # this is a 100% overlap with the create test above...
      fill_product_data(prod_interface)

      expect{ prod_interface.read("foo") }.not_to raise_exception
      expect( prod_interface.read("foo").to_h ).to include(code: "foo", name: "bar")
    end

    it "calls ConnectionPool#client" do
      expect( interface._connection ).to receive(:client).at_least(:once).and_call_original
      interface.read(99)
    end

  end # of #read


  describe "#list" do
    before { fill_data(interface) }

    it "has an optional selection parameter, a hash" do
      # Actually it does not have to be a hash, but FTTB we only support that.
      expect{ interface.list(name: "Barney") }.not_to raise_exception
    end

    it "returns an array of Octothorpes that match the records" do
      # convert each OT to a hash and remove the ID key
      arr = interface.list.map {|ot| x = ot.to_h; x.delete(:id); x }

      expect( arr ).to match_array @data
    end

    it "returns a subset of records based on the selection parameter" do
      expect( interface.list(name: "Fred").size ).to eq 1

      expect( interface.list(name: "Betty").first.to_h ).
        to include(name: "Betty")

    end

    it "returns an empty Array if nothing matches" do
      expect( interface.list(name: "Yogi") ).to eq([])
    end

    it "raises ArgumentError if the selection criteria is nonsensical" do
      expect{ interface.list("foo") }.to raise_exception ArgumentError
    end

    it "calls ConnectionPool#client" do
      expect( interface._connection ).to receive(:client).at_least(:once).and_call_original
      interface.list
    end

  end # of #list
  

  describe "#update" do
    before { fill_data(interface) }

    let(:id) { interface.list.first[:id] }

    it "updates the record at ID with record parameter" do
      record = {name: "Booboo", price: 99.99}
      interface.update(id, record)

      expect( float_price( interface.read(id).to_h ) ).to include(record)
    end

    it "raises a CantContinue if anything weird happens with the ID" do
      expect{ interface.update(99, name: "Booboo") }.
        to raise_exception CantContinue

    end

    it "raises a DatabaseError if anything weird happens with the record" do
      expect{ interface.update(id, smarts: "more") }.
        to raise_exception DatabaseError

    end

    it "has no problem with record values of nil" do
      record = {name: "Ranger", price: nil}
      expect{ interface.update(id, record) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include(record)
    end

    it "has no problem with strings containing special characters" do
      record = {name: %Q|T'Challa"|, price: nil}
      expect{ interface.update(id, record) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include(record)
    end

    it "has no problem with non-integer keys" do
      fill_product_data(prod_interface)
      expect{ prod_interface.update("foo", name: "baz") }.not_to raise_error
      expect( prod_interface.read("foo").to_h[:name] ).to eq "baz"
    end

    it "calls ConnectionPool#client" do
      expect( interface._connection ).to receive(:client).at_least(:once).and_call_original
      record = {name: "Booboo", price: 99.99}
      interface.update(id, record)
    end

  end # of #update


  describe "#delete" do
    let(:id) { interface.list.first[:id] }

    before { fill_data(interface) }

    it "raises CantContinue if anything hinky happens with the id" do
      expect{ interface.delete(:foo) }.to raise_exception CantContinue
      expect{ interface.delete(99)   }.to raise_exception CantContinue
    end

    it "makes the record at ID go away" do
      expect( list_contains(interface, id) ).to be_truthy
      interface.delete(id)
      expect( list_contains(interface, id) ).to be_falsy
    end

    it "has no roblem with non-integer keys" do
      fill_product_data(prod_interface)
      expect( list_contains(prod_interface, "foo") ).to be_truthy
      prod_interface.delete("foo")
      expect( list_contains(prod_interface, "foo") ).to be_falsy
    end

    it "calls ConnectionPool#client" do
      expect( interface._connection ).to receive(:client).at_least(:once).and_call_original
      interface.delete(id)
    end

  end # of #delete


  describe "#execute" do
    let(:sql) { "delete from customer where cast(price as numeric) < 2.0;" }

    before { fill_data(interface) }

    it "requires an SQL string" do
      expect{ interface.execute      }.to raise_exception ArgumentError
      expect{ interface.execute(nil) }.to raise_exception ArgumentError
      expect{ interface.execute(14)  }.to raise_exception ArgumentError
    end

    it "raises some sort of Pod4 error if it runs into problems" do
      expect{ interface.execute("delete from not_a_table") }.
        to raise_exception Pod4Error

    end

    it "executes the string" do
      expect{ interface.execute(sql) }.not_to raise_exception
      expect( interface.list.size ).to eq(@data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include "Barney"
    end

    it "calls ConnectionPool#client" do
      expect( interface._connection ).to receive(:client).at_least(:once).and_call_original
      interface.execute(sql)
    end

  end # of #execute


  describe "#executep" do
    let(:sql) { "delete from customer where cast(price as numeric) < %s and name = %s;" }

    before { fill_data(interface) }

    it "requires an SQL string" do
      expect{ interface.executep      }.to raise_exception ArgumentError
      expect{ interface.executep(nil) }.to raise_exception ArgumentError
      expect{ interface.executep(14)  }.to raise_exception ArgumentError
    end

    it "raises some sort of Pod4 error if it runs into problems" do
      expect{ interface.executep("delete from not_a_table where foo = %s", 12) }.
        to raise_exception Pod4Error

    end

    it "executes the string with the given parameters" do
      expect{ interface.executep(sql, 12.0, "Barney") }.not_to raise_exception
      expect( interface.list.size ).to eq(@data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include "Barney"
    end

    it "calls ConnectionPool#client" do
      expect( interface._connection ).to receive(:client).at_least(:once).and_call_original
      interface.executep(sql, 12.0, "Barney")
    end

  end # of #executep


  describe "#select" do
    before { fill_data(interface) }

    it "requires an SQL string" do
      expect{ interface.select      }.to raise_exception ArgumentError
      expect{ interface.select(nil) }.to raise_exception ArgumentError
      expect{ interface.select(14)  }.to raise_exception ArgumentError
    end

    it "raises some sort of Pod4 error if it runs into problems" do
      expect{ interface.select("select * from not_a_table") }.
        to raise_exception Pod4Error

    end

    it "returns the result of the sql" do
      sql1 = "select name from customer where cast(price as numeric) < 2.0;"
      sql2 = "select name from customer where cast(price as numeric) < 0.0;"

      expect{ interface.select(sql1) }.not_to raise_exception
      expect( interface.select(sql1) ).to eq( [{name: "Barney"}] )
      expect( interface.select(sql2) ).to eq( [] )
    end

    it "works if you pass a non-select" do
      # By which I mean: still executes the SQL; returns []
      sql = "delete from customer where cast(price as numeric) < 2.0;"
      ret = interface.select(sql)

      expect( interface.list.size ).to eq(@data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include "Barney"
      expect( ret ).to eq( [] )
    end

    it "calls ConnectionPool#client" do
      expect( interface._connection ).to receive(:client).at_least(:once).and_call_original
      sql = "select name from customer;"
      interface.select(sql)
    end

  end # of #select


  describe "#selectp" do
    before { fill_data(interface) }

    it "requires an SQL string" do
      expect{ interface.selectp      }.to raise_exception ArgumentError
      expect{ interface.selectp(nil) }.to raise_exception ArgumentError
      expect{ interface.selectp(14)  }.to raise_exception ArgumentError
    end

    it "raises some sort of Pod4 error if it runs into problems" do
      expect{ interface.selectp("select * from not_a_table where thingy = %s", 12) }.
        to raise_exception Pod4Error

    end

    it "returns the result of the sql" do
      sql = "select name from customer where cast(price as numeric) < %s;"

      expect{ interface.selectp(sql, 2.0) }.not_to raise_exception
      expect( interface.selectp(sql, 2.0) ).to eq( [{name: "Barney"}] )
      expect( interface.selectp(sql, 0.0) ).to eq( [] )
    end

    it "works if you pass a non-select" do
      sql = "delete from customer where cast(price as numeric) < %s;"
      ret = interface.selectp(sql, 2.0)

      expect( interface.list.size ).to eq(@data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include "Barney"
      expect( ret ).to eq( [] )
    end

    it "calls ConnectionPool#client" do
      expect( interface._connection ).to receive(:client).at_least(:once).and_call_original
      sql = "select name from customer where cast(price as numeric) < %s;"
      interface.selectp(sql, 2.0)
    end

  end # of #selectp


  describe "#new_connection" do
     
    it "returns a PG Client object" do
      expect( interface.new_connection @connect_hash ).to be_a PG::Connection
    end
    
  end # of #new_connection


  describe "#close_connection" do

    it "closes the given PG Client object" do
      client = interface.new_connection(@connect_hash)

      expect( client ).to receive(:finish)

      interface.close_connection(client)
    end

  end # of #close_connection
  
end

