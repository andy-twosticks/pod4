require "octothorpe"

require "pod4/model"
require "pod4/null_interface"


describe "Model" do

  ##
  # We define a model class to test, since in normal operation we would never use Model directly,
  # and since it needs an inner Interface.
  #
  let(:customer_model_class) do
    Class.new Pod4::Model do
      attr_columns :id, :name, :groups
      attr_columns :price  # specifically testing multiple calls to attr_columns

      set_interface NullInterface.new(:id, :name, :price, :groups, 
        [ {id: 1, name: "Gomez",     price: 1.23, groups: "trains"       },
          {id: 2, name: "Morticia",  price: 2.34, groups: "spanish"      },
          {id: 3, name: "Wednesday", price: 3.45, groups: "school"       },
          {id: 4, name: "Pugsley",   price: 4.56, groups: "trains,school"} ] )

      def map_to_model(ot)
        super
        @groups = @groups ? @groups.split(",") : []
        self
      end

      def map_to_interface
        x = super
        g = (x.>>.groups || []).join(",")
        x.merge(groups: g)
      end

      def fake_an_alert(*args)
        add_alert(*args) #private method
      end

      def validate(vmode)
        add_alert(:error, "falling over now") if name == "fall over"
      end

      def reset_alerts; @alerts = []; end
    end
  end

  # Here's a second model for a non-autoincrementing table
  let(:product_model_class) do
    Class.new Pod4::Model do
      i = NullInterface.new(:code, :level, [{code: "foo", level: 1},
                                            {code: "bar", level: 2}] )

      i.id_ai = false

      attr_columns :code, :level
      set_interface i
    end
  end


  def without_groups(ot)
    ot.to_h.reject {|k,_| k == :groups}
  end

  def arr_without_groups(arr)
    arr
      .map {|m| without_groups(m.to_ot) }
      .flatten

  end

  let(:records) do
    [ {id: 1, name: "Gomez",     price: 1.23, groups: "trains"       },
      {id: 2, name: "Morticia",  price: 2.34, groups: "spanish"      },
      {id: 3, name: "Wednesday", price: 3.45, groups: "school"       },
      {id: 4, name: "Pugsley",   price: 4.56, groups: "trains,school"} ]

  end

  let(:recordsx) do
    records.map {|h| h.reject{|k,_| k == :groups} }.flatten
  end

  let(:records_as_ot)  { records.map{|r| Octothorpe.new(r) } }
  let(:recordsx_as_ot) { recordsx.map{|r| Octothorpe.new(r) } }

  # model is just a plain newly created object that you can call read on.
  # model2 and model3 are in an identical state - they have been filled with a
  # read(). We have two so that we can RSpec "allow" on one and not the other.

  let(:model) { customer_model_class.new(2) }

  let(:model2) do
    m = customer_model_class.new(3)

    #allow( m.interface ).to receive(:read).and_return( Octothorpe.new(records[2]) )
    m.read.or_die
  end

  let(:model3) do
    m = customer_model_class.new(4)

    #allow( m.interface ).to receive(:read).and_return( Octothorpe.new(records[3]) )
    m.read.or_die
  end


  describe "Model.attr_columns" do

    it "requires a list of columns" do
      expect( customer_model_class ).to respond_to(:attr_columns).with(1).argument
    end

    it "exposes the columns just like attr_accessor" do
      expect( customer_model_class.new ).to respond_to(:id)
      expect( customer_model_class.new ).to respond_to(:name)
      expect( customer_model_class.new ).to respond_to(:price)
      expect( customer_model_class.new ).to respond_to(:groups)
      expect( customer_model_class.new ).to respond_to(:id=)
      expect( customer_model_class.new ).to respond_to(:name=)
      expect( customer_model_class.new ).to respond_to(:price=)
      expect( customer_model_class.new ).to respond_to(:groups=)
    end

    # it adds the columns to Model.columns -- covered by the columns test
  end


  describe "Model.columns" do

    it "lists the columns" do
      expect( customer_model_class.columns ).to match_array( [:id,:name,:price,:groups] )
    end

  end


  describe "Model.set_interface" do

    it "requires an Interface object" do
      expect( customer_model_class ).to respond_to(:set_interface).with(1).argument
    end

    # it "sets interface" - covered by the interface test
  end

  
  describe "Model.interface" do

    it "is the interface object" do
      expect( customer_model_class.interface ).to be_a_kind_of NullInterface
      expect( customer_model_class.interface.id_fld ).to eq :id
    end

  end


  describe "Model.list" do
    let(:list1) { customer_model_class.list }

    it "allows an optional selection parameter" do
      expect{ customer_model_class.list                }.not_to raise_exception
      expect{ customer_model_class.list(name: "Betty") }.not_to raise_exception
    end

    it "returns an array of customer_model_class records" do
      expect( list1 ).to be_a_kind_of Array
      expect( list1 ).to all(be_a_kind_of customer_model_class)
    end

    it "returns the data from the interface" do
      expect( list1.size ).to eq records.size
      expect( arr_without_groups(list1) ).to include( *recordsx )
    end

    it "honours passed selection criteria" do
      list = customer_model_class.list(price: 2.34)
      expect( list.size ).to eq 1
      expect( arr_without_groups(list).first ).to eq( recordsx[1] )
    end

    it "returns an empty array if nothing matches" do
      expect( customer_model_class.list(price: 3.21) ).to eq []
    end

    it "returns an empty array if there are no records" do
      customer_model_class.list.each{|r| r.read; r.delete}
      expect( customer_model_class.list ).to eq []
    end

    it "calls map_to_model to set the record data" do
      # groups is an array because we coded it to represent that way in the model above.
      expect( customer_model_class.list.last.groups ).to eq(["trains", "school"])
    end

  end # of Model.list


  describe "#new" do

    it "takes an optional ID" do
      expect{ customer_model_class.new    }.not_to raise_exception
      expect{ customer_model_class.new(1) }.not_to raise_exception
    end

    it "sets the ID attribute" do
      expect( customer_model_class.new(23).model_id ).to eq 23
    end

    it "sets the status to unknown" do
      expect( customer_model_class.new.model_status ).to eq :unknown
    end

    it "initializes the alerts attribute" do
      expect( customer_model_class.new.alerts ).to eq([])
    end

    it "doesn't freak out if the non-autoincrementing ID is not an integer" do
      expect{ product_model_class.new("france") }.not_to raise_exception
      expect( product_model_class.new("france").model_id ).to eq "france"
    end

  end # of #new


  describe "#interface" do

    it "returns the interface set in the class definition, again" do
      expect( customer_model_class.new.interface ).to be_a_kind_of NullInterface
      expect( customer_model_class.new.interface.id_fld ).to eq :id
    end

  end # of #interface


  describe "#columns" do

    it "returns the attr_columns list from the class definition" do
      expect( customer_model_class.new.columns ).
        to match_array( [:id,:name,:price,:groups] )

    end

  end # of #columns


  describe "#alerts" do

    it "returns the list of alerts against the model" do
      cm = customer_model_class.new
      cm.fake_an_alert(:warning, :foo, "one")
      cm.fake_an_alert(:error,   :bar, "two")

      expect( cm.alerts.size ).to eq 2
      expect( cm.alerts.map{|a| a.message} ).to match_array(%w|one two|)
    end

  end # of #alerts


  describe "#add_alert" do
    # add_alert is a private method, which is only supposed to be called within a subclass of
    # Model. So we test it by calling our alert faking method

    it "requires type, message or type, field, message" do
      expect{ model.fake_an_alert        }.to raise_exception ArgumentError
      expect{ model.fake_an_alert(nil)   }.to raise_exception ArgumentError
      expect{ model.fake_an_alert("foo") }.to raise_exception ArgumentError

      expect{ model.fake_an_alert(:error, "foo") }.not_to raise_exception
      expect{ model.fake_an_alert(:warning, :name, "bar") }.
        not_to raise_exception

    end

    it "only allows valid types" do
      [:brian, :werning, nil, :alert, :danger].each do |l|
        expect{ model.fake_an_alert(l, "foo") }.to raise_exception ArgumentError
      end

      [:warning, :error, :success, :info].each do |l|
        expect{ model.fake_an_alert(l, "foo") }.not_to raise_exception
      end

    end

    it "creates an Alert and adds it to @alerts" do
      lurch = "Dnhhhhhh"
      model.fake_an_alert(:error, :price, lurch)

      expect( model.alerts.size ).to eq 1
      expect( model.alerts.first ).to be_a_kind_of Pod4::Alert
      expect( model.alerts.first.message ).to eq lurch
    end

    it "sets @model_status if the type is worse than @model_status" do
      model.fake_an_alert(:warning, :price, "xoo")
      expect( model.model_status ).to eq :warning

      model.fake_an_alert(:success, :price, "flom")
      expect( model.model_status ).to eq :warning

      model.fake_an_alert(:info, :price, "flom")
      expect( model.model_status ).to eq :warning

      model.fake_an_alert(:error, :price, "qar")
      expect( model.model_status ).to eq :error

      model.fake_an_alert(:warning, :price, "drazq")
      expect( model.model_status ).to eq :error
    end

    it "ignores a new alert if identical to an existing one" do
      lurch = "Dnhhhhhh"
      2.times { model.fake_an_alert(:error, :price, lurch) }

      expect( model.alerts.size ).to eq 1
    end

  end # of #add_alert


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

      expect( model.id    ).to eq ot.>>.id
      expect( model.name  ).to eq ot.>>.name
      expect( model.price ).to eq ot.>>.price
    end
    
    it "only sets the attributes on the model that it is given" do
      otx = Octothorpe.new(name: "Piggy", price: 98.76, weapon: "rake")

      expect{ model3.set(otx) }.not_to raise_exception
      expect( model3.id     ).to eq 4
      expect( model3.name   ).to eq "Piggy"
      expect( model3.price  ).to eq 98.76
      expect( model3.groups ).to eq( ot.>>.groups.split(",") )
    end

  end # of #set


  describe "#to_ot" do

    it "returns an Octothorpe made of the attribute columns, including the ID field" do
      m1 = customer_model_class.new
      expect( m1.to_ot ).to be_a_kind_of Octothorpe
      expect( m1.to_ot.to_h ).to eq( {id: nil, name: nil, price:nil, groups:nil} )

      m2 = customer_model_class.new(1)
      m2.read
      expect( m2.to_ot ).to be_a_kind_of Octothorpe
      expect( without_groups(m2.to_ot) ).to eq recordsx[0]

      m3 = customer_model_class.new(2)
      m3.read
      expect( m3.to_ot ).to be_a_kind_of Octothorpe
      expect( without_groups(m3.to_ot) ).to eq recordsx[1]
    end

  end # of #to_ot


  describe "#map_to_model" do

    it "sets the columns, with groups as an array" do
      # testing the custom typecasting in customer_model_class

      cm = customer_model_class.new
      cm.map_to_model(records.last)

      expect( cm.groups ).to eq( ["trains","school"] )
    end

  end # of #map_to_model


  describe "#map_to_interface" do

    it "returns the columns, with groups as a list" do
      # testing the custom typecasting in customer_model_class

      cm = customer_model_class.new
      cm.map_to_model(records.last)

      expect( cm.map_to_interface ).to be_an Octothorpe
      expect( cm.map_to_interface.>>.groups ).to eq( "trains,school" )
    end

  end # of #map_to_interface


  describe "#raise_exceptions" do

    it "is also known as .or_die" do
      cm = customer_model_class.new
      expect( cm.method(:raise_exceptions) ).to eq( cm.method(:or_die) )
    end

    it "raises ValidationError if model status is :error" do
      model.fake_an_alert(:error, :price, "qar")
      expect{ model.raise_exceptions }.to raise_exception Pod4::ValidationError
    end

    it "does nothing if model status is not :error" do
      expect{ model.raise_exceptions }.not_to raise_exception

      model.fake_an_alert(:info, :price, "qar")
      expect{ model.raise_exceptions }.not_to raise_exception

      model.fake_an_alert(:success, :price, "qar")
      expect{ model.raise_exceptions }.not_to raise_exception

      model.fake_an_alert(:warning, :price, "qar")
      expect{ model.raise_exceptions }.not_to raise_exception
    end

  end # of #raise_exceptions


  describe "#create" do
    let (:new_model) { customer_model_class.new }

    it "takes no parameters" do
      expect{ customer_model_class.new.create(12) }.to raise_exception ArgumentError
      expect{ customer_model_class.new.create     }.not_to raise_exception
    end

    it "returns self" do
      expect( new_model.create ).to eq new_model
    end

    it "calls validate and passes the parameter" do
      expect( new_model ).to receive(:validate).with(:create)

      new_model.name = "foo"
      new_model.create
    end

    it "calls create on the interface if the record is good" do
      expect( customer_model_class.interface ).to receive(:create)
      customer_model_class.new.create

      new_model.fake_an_alert(:warning, :name, "foo")
      expect( new_model.interface ).to receive(:create)
      new_model.create
    end

    it "doesn't call create on the interface if the record is bad" do
      new_model.fake_an_alert(:error, :name, "foo")
      expect( new_model.interface ).not_to receive(:create)
      new_model.create
    end

    it "sets model status to :okay if it was :unknown" do
      new_model.id   = 5
      new_model.name = "Lurch"
      new_model.create

      expect( new_model.model_status ).to eq :okay
    end

    it "leaves the model status alone if it was not :unknown" do
      new_model.id   = 5
      new_model.name = "Lurch"
      new_model.create

      new_model.fake_an_alert(:warning, :price, "qar")
      expect( new_model.model_status ).to eq :warning
    end

    it "calls map_to_interface to get record data" do
      m = customer_model_class.new

      expect( m ).to receive(:map_to_interface).and_call_original

      m.id   = 5
      m.name = "Lurch"
      m.create
    end

    it "doesn't freak out if the ID field (non-autoincrementing) is not an integer" do
      m = product_model_class.new("baz").read
      m.level = 99
      expect{ m.create }.not_to raise_error
    end

    it "creates an alert instead when the interface raises WeakError" do
      allow( new_model.interface ).to receive(:create).and_raise Pod4::WeakError, "foo"

      new_model.id   = 5
      new_model.name = "Lurch"
      expect{ new_model.create }.not_to raise_exception
      expect( new_model.model_status ).to eq :error
      expect( new_model.alerts.map(&:message) ).to include( include "foo" )
    end

  end # of #create


  describe "#read" do

    it "takes no parameters" do
      expect{ customer_model_class.new.create(12) }.to raise_exception ArgumentError
      expect{ customer_model_class.new.create     }.not_to raise_exception
    end

    it "returns self" do
      expect( model.read ).to eq model
    end

    it "calls read on the interface" do
      expect( model.interface ).to receive(:read).with(2).and_call_original
      model.read
    end

    it "calls validate and passes the parameter" do
      expect( model ).to receive(:validate).with(:read)
      model.read
    end

    it "sets the attribute columns using map_to_model" do
      ot = records_as_ot.last
      cm = customer_model_class.new(4).read
      expect( cm.name  ).to eq ot.>>.name
      expect( cm.price ).to eq ot.>>.price
      expect( cm.groups ).to be_a_kind_of(Array)
      expect( cm.groups ).to eq( ot.>>.groups.split(",") )
    end

    it "sets model status to :okay if it was :unknown" do
      ot = records_as_ot.last
      model.read
      expect( model.model_status ).to eq :okay
    end

    it "leaves the model status alone if it was not :unknown" do
      ot = records_as_ot.last
      model.fake_an_alert(:warning, :price, "qar")
      model.read
      expect( model.model_status ).to eq :warning
    end

    it "doesn't freak out if the (non-autoincrementing) ID is non-integer" do
      expect{ product_model_class.new("foo").read }.not_to raise_error
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

    it "creates an alert instead when the interface raises WeakError" do
      allow( model.interface ).to receive(:read).and_raise Pod4::WeakError, "foo"

      expect{ model.read }.not_to raise_exception
      expect( model.model_status ).to eq :error
      expect( model.alerts.map(&:message) ).to include( include "foo" )
    end

  end # of #read


  describe "#update" do

    it "takes no parameters" do
      expect{ model2.update(12) }.to raise_exception ArgumentError
      expect{ model2.update     }.not_to raise_exception
    end

    it "returns self" do
      expect( model2.update ).to eq model2
    end

    it "raises a Pod4Error if model status is :unknown" do
      expect( model.model_status ).to eq :unknown
      expect{ model.update }.to raise_exception Pod4::Pod4Error
    end

    it "raises a Pod4Error if model status is :deleted" do
      model2.delete
      expect{ model2.update }.to raise_exception Pod4::Pod4Error
    end

    it "calls validate and passes the parameter" do
      expect( model2 ).to receive(:validate).with(:update)

      model2.name = "foo"
      model2.update
    end

    it "calls update on the interface if the validation passes" do
      expect( model3.interface ).to receive(:update)

      model3.update
    end

    it "doesn't call update on the interface if the validation fails" do
      expect( model3.interface ).not_to receive(:update)

      model3.name = "fall over"  # triggers validation
      model3.update
    end

    it "calls map_to_interface to get record data" do
      expect( model3 ).to receive(:map_to_interface)
      model3.update
    end

    it "doesn't freak out if the (non_autoincrementing) ID is non-integer" do
      m = product_model_class.new("bar").read
      expect{ m.update }.not_to raise_error
    end

    context "when the record already has error alerts" do
      it "passes if there is no longer anything wrong" do
        expect( model3.interface ).to receive(:update)

        model3.fake_an_alert(:error, "bad things")
        model3.update
      end
    end

    it "creates an alert instead when the interface raises WeakError" do
      allow( model3.interface ).to receive(:update).and_raise Pod4::WeakError, "foo"

      expect{ model3.update }.not_to raise_exception
      expect( model3.model_status ).to eq :error
      expect( model3.alerts.map(&:message) ).to include( include "foo" )
    end

  end # of #update


  describe "#delete" do

    it "takes no parameters" do
      expect{ model2.delete(12) }.to raise_exception ArgumentError
      expect{ model2.delete     }.not_to raise_exception
    end

    it "returns self" do
      expect( model2.delete ).to eq model2
    end

    it "raises a Pod4Error if model status is :unknown" do
      expect( model.model_status ).to eq :unknown
      expect{ model.delete }.to raise_exception Pod4::Pod4Error
    end

    it "raises a Pod4Error if model status is :deleted"do
      model2.delete
      expect{ model2.delete }.to raise_exception Pod4::Pod4Error
    end

    it "calls validate and passes the parameter" do
      expect( model2 ).to receive(:validate).with(:delete)
      model2.delete
    end

    it "calls delete on the interface if the model status is good" do
      expect( model3.interface ).
        to receive(:delete)

      model3.delete 
    end

    it "calls delete on the interface if the model status is bad" do
      expect( model3.interface ).
        to receive(:delete)

      model3.fake_an_alert(:error, :price, "qar")
      model3.delete 
    end

    it "still gives you full access to the data after a delete" do
      model2.delete

      expect( model2.id    ).to eq records_as_ot[2].>>.id
      expect( model2.name  ).to eq records_as_ot[2].>>.name
      expect( model2.price ).to eq records_as_ot[2].>>.price
    end

    it "sets status to :deleted" do
      model2.delete
      expect( model2.model_status ).to eq :deleted
    end

    it "doesn't freak out if the (non-autoincrementing) ID is non-integer" do
      m = product_model_class.new("bar").read
      expect{ m.delete }.not_to raise_error
    end

    it "creates an alert instead when the interface raises WeakError" do
      allow( model3.interface ).to receive(:delete).and_raise Pod4::WeakError, "foo"

      expect{ model3.delete }.not_to raise_exception
      expect( model3.alerts.map(&:message) ).to include( include "foo" )
    end

  end # of #delete

end

