require "pod4/null_interface"

require_relative "shared_examples_for_interface"


describe NullInterface do

  def list_contains(id)
    interface.list.find {|x| x[interface.id_fld] == id }
  end

  # An autoincrementing interface
  let(:data) do
    [ {id: 1, name: "Barney", price: 1.11},
      {id: 2, name: "Fred",   price: 2.22},
      {id: 3, name: "Betty",  price: 3.33} ]
  end
  let (:interface) { NullInterface.new(:id, :name, :price, data) }

  # A non-autoincrementing interface
  let(:data2) do
    [ {code: "foo", level: 1},
      {code: "bar", level: 2},
      {code: "baz", level: 3} ]
  end

  let (:interface2) do
    i = NullInterface.new(:code, :level, data2)
    i.id_ai = false
    i
  end


  it_behaves_like "an interface" do
    let(:record)    { {name: "barney", price:1.11} }
    let(:interface) { NullInterface.new( :id, :name, :price, [record]) }
  end


  describe "#new" do

    it "requires a list of columns and an array of hashes" do
      expect{ NullInterface.new        }.to raise_exception ArgumentError
      expect{ NullInterface.new(nil)   }.to raise_exception ArgumentError
      expect{ NullInterface.new("foo") }.to raise_exception ArgumentError

      expect{ NullInterface.new(:one, [{one:1}]) }.not_to raise_exception
    end

    it "defaults autoincrement to true" do
      expect( interface.id_ai ).to eq true
    end

    it "allows you to set autoincrement to false" do
      ni = NullInterface.new(:one, [{one:1}])
      ni.id_ai = false
      expect( ni.id_ai ).to eq false
    end

  end # of #new


  describe "#create" do

    let(:hash) { {name: "Bam-Bam", price: 4.44} }
    let(:ot)   { Octothorpe.new(name: "Wilma", price: 5.55) }

    it "creates the record when given a hash" do
      id = interface.create(hash)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include hash
    end

    it "creates the record when given an Octothorpe" do
      id = interface.create(ot)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include ot.to_h
    end

    it "raises an ArgumentError when the key is not AI and the record is missing the key" do
      expect{ interface2.create(level: 55) }.to raise_error ArgumentError
    end

    it "sets the ID field to the correct integer when autoincrement is true" do
      count = interface.list.size
      id = interface.create(ot)
      expect( id ).to eq(count + 1)
    end

    it "sets the ID field to whatever you set in the record when autoincrement is false" do
      id = interface2.create Octothorpe.new(code: "flong", level: 9)
      expect( id ).to eq "flong"
    end

  end # of #create


  describe "#read" do

    it "returns the record for the id as an Octothorpe" do
      expect( interface.read(1)      ).to be_a_kind_of Octothorpe
      expect( interface.read(2).to_h ).to include(name: "Fred", price: 2.22)
    end

    it "returns an empty Octothorpe if no record matches the ID" do
      expect{ interface.read(:foo) }.not_to raise_exception
      expect( interface.read(:foo) ).to be_a_kind_of Octothorpe
      expect( interface.read(:foo) ).to be_empty
    end

  end # of #read


  describe "#list" do

    it "has an optional selection parameter, a hash" do
      expect{ interface.list }.not_to raise_exception
      expect{ interface.list(name: "Barney") }.not_to raise_exception
    end

    it "returns an array of Octothorpes that match the records" do
      arr = interface.list.map(&:to_h)
      expect( arr ).to match_array data
    end

    it "returns a subset of records based on the selection parameter" do
      expect( interface.list(name: "Fred").size ).to eq 1

      expect( interface.list(name: "Betty").first.to_h ).
        to include(name: "Betty", price: 3.33)

    end

    it "returns an empty Array if nothing matches" do
      expect( interface.list(name: "Yogi") ).to eq([])
    end

    it "returns an empty array if there is no data" do
      interface.list.each {|x| interface.delete(x[interface.id_fld]) }
      expect( interface.list ).to eq([])
    end

  end # of #list
  

  describe "#update" do

    it "updates the record at ID with record parameter" do
      record = {price: 99.99}
      interface.update(1, record)

      expect( interface.read(1).to_h ).to include(record)
    end

  end # of #update


  describe "#delete" do
    it "raises CantContinue if anything hinky happens with the ID" do
      expect{ interface.delete(:foo) }.to raise_exception CantContinue
      expect{ interface.delete(99)   }.to raise_exception CantContinue
    end

    it "makes the record at ID go away" do
      expect( list_contains(1) ).to be_truthy
      interface.delete(1)
      expect( list_contains(1) ).to be_falsy
    end

  end # of #delete


end

