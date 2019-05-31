require "octothorpe"

require "pod4/model"
require "pod4/null_interface"


##
# This test covers a model with an autoincrementing ID but where the ID field is not named as an
# attribute. Pre-1.0 you _had_ to do it this way. No reason why it would not be an option going
# forward.
#
describe "(Autoincrementing Model with No ID Attribute)" do

  let(:customer_model_class) do
    Class.new Pod4::Model do
      attr_columns :name, :groups, :price
      set_interface NullInterface.new(:id, :name, :price, :groups, 
        [ {id: 1, name: "Gomez",     price: 1.23, groups: "trains"       },
          {id: 2, name: "Morticia",  price: 2.34, groups: "spanish"      },
          {id: 3, name: "Wednesday", price: 3.45, groups: "school"       },
          {id: 4, name: "Pugsley",   price: 4.56, groups: "trains,school"} ] )

    end
  end

  let(:records) do
    [ {id: 1, name: "Gomez",     price: 1.23, groups: "trains"       },
      {id: 2, name: "Morticia",  price: 2.34, groups: "spanish"      },
      {id: 3, name: "Wednesday", price: 3.45, groups: "school"       },
      {id: 4, name: "Pugsley",   price: 4.56, groups: "trains,school"} ]

  end

  let(:records_as_ot)  { records.map{|r| Octothorpe.new(r) } }

  # model is just a plain newly created object that you can call read on.
  # model2 and model3 are in an identical state - they have been filled with a
  # read(). We have two so that we can RSpec "allow" on one and not the other.

  let(:model) { customer_model_class.new(2) }

  let(:model2) do
    m = customer_model_class.new(3)

    allow( m.interface ).to receive(:read).and_return( Octothorpe.new(records[2]) )
    m.read.or_die
  end

  let(:model3) do
    m = customer_model_class.new(4)

    allow( m.interface ).to receive(:read).and_return( Octothorpe.new(records[3]) )
    m.read.or_die
  end


  describe "Model.list" do
    let(:list1) { customer_model_class.list }

    it "returns an array of customer_model_class records" do
      expect( list1 ).to be_a_kind_of Array
      expect( list1 ).to all(be_a_kind_of customer_model_class)
    end

    it "returns the data from the interface" do
      expect( list1.size ).to eq records.size
      expect( list1.map(&:to_ot).map(&:to_h) ).to match_array(records)
    end

  end # of Model.list


  describe "#columns" do

    it "returns the attr_columns list from the class definition" do
      expect( customer_model_class.new.columns ).
        to match_array( [:name,:price,:groups] )

    end

  end # of #columns


  describe "#set" do
    let (:ot) { records_as_ot[3] }

    it "takes an Octothorpe or a Hash" do
      expect{ model.set       }.to raise_exception ArgumentError
      expect{ model.set(nil)  }.to raise_exception ArgumentError
      expect{ model.set(:foo) }.to raise_exception ArgumentError

      expect{ model.set(ot) }.not_to raise_exception 
    end

    it "returns self" do
      expect( model.set(ot) ).to eq model
    end

    it "sets the attribute columns from the hash" do
      model.set(ot)

      expect( model.name  ).to eq ot.>>.name
      expect( model.price ).to eq ot.>>.price
    end
    
  end # of #set


  describe "#to_ot" do

    it "returns an Octothorpe made of the attribute columns, including the missing ID field" do
      m1 = customer_model_class.new
      expect( m1.to_ot ).to be_a_kind_of Octothorpe
      expect( m1.to_ot.to_h ).to eq( {id: nil, name: nil, price:nil, groups:nil} )

      m2 = customer_model_class.new(1)
      m2.read
      expect( m2.to_ot ).to be_a_kind_of Octothorpe
      expect( m2.to_ot ).to eq records_as_ot[0]

      m2 = customer_model_class.new(2)
      m2.read
      expect( m2.to_ot ).to be_a_kind_of Octothorpe
      expect( m2.to_ot ).to eq records_as_ot[1] 
    end

  end # of #to_ot


  describe "#map_to_model" do

    it "sets the columns" do
      cm = customer_model_class.new
      cm.map_to_model(records.last)

      expect( cm.groups ).to eq "trains,school"
    end

  end # of #map_to_model


  describe "#map_to_interface" do

    it "returns the columns" do
      cm = customer_model_class.new
      cm.map_to_model(records.last)

      expect( cm.map_to_interface ).to be_an Octothorpe
      expect( cm.map_to_interface.>>.groups ).to eq( "trains,school" )
    end

    it "includes the ID field" do
      cm = customer_model_class.new(2).read

      expect( cm.map_to_interface ).to be_an Octothorpe
      expect( cm.map_to_interface.keys ).to include(:id)
    end

  end # of #map_to_interface


  describe "#create" do

    it "calls map_to_interface to get record data" do
      m = customer_model_class.new(5)

      expect( m ).to receive(:map_to_interface).and_call_original

      m.name = "Lurch"
      m.create
    end

  end # of #create


  describe "#read" do

    it "calls read on the interface" do
      expect( model.interface ).to receive(:read).with(2).and_call_original
      model.read
    end

    it "sets the attribute columns using map_to_model" do
      ot = records_as_ot.last
      allow( model.interface ).to receive(:read).and_return( ot )

      cm = customer_model_class.new(1).read
      expect( cm.name  ).to eq ot.>>.name
      expect( cm.price ).to eq ot.>>.price
      expect( cm.groups ).to eq ot.>>.groups
    end

    context "if the interface.read returns an empty Octothorpe" do
      let(:missing) { customer_model_class.new(99) }

      it "doesn't throw an exception" do
        expect{ missing.read }.not_to raise_exception
      end

      it "raises an error alert" do
        expect( missing.read.model_status ).to eq :error
        expect( missing.read.alerts.first.type ).to eq :error
      end
    end

  end # of #read


  describe "#update" do

    it "raises a Pod4Error if model status is :unknown" do
      expect( model.model_status ).to eq :unknown
      expect{ model.update }.to raise_exception Pod4::Pod4Error
    end

    it "raises a Pod4Error if model status is :deleted" do
      model2.delete
      expect{ model2.update }.to raise_exception Pod4::Pod4Error
    end

    it "calls map_to_interface to get record data" do
      expect( model3 ).to receive(:map_to_interface)
      model3.update
    end

  end # of #update


  describe "#delete" do

    it "raises a Pod4Error if model status is :unknown" do
      expect( model.model_status ).to eq :unknown
      expect{ model.delete }.to raise_exception Pod4::Pod4Error
    end

    it "raises a Pod4Error if model status is :deleted"do
      model2.delete
      expect{ model2.delete }.to raise_exception Pod4::Pod4Error
    end

    it "still gives you full access to the data after a delete" do
      model2.delete

      expect( model2.name  ).to eq records_as_ot[2].>>.name
      expect( model2.price ).to eq records_as_ot[2].>>.price
    end

    it "sets status to :deleted" do
      model2.delete
      expect( model2.model_status ).to eq :deleted
    end

  end # of #delete

end

