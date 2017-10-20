require 'octothorpe'

require 'pod4/model'
require 'pod4/null_interface'


describe 'CustomerModel' do

  ##
  # We define a model class to test, since in normal operation we would never use Model directly,
  # and since it needs an inner Interface.
  #
  # We define an inner class based on the genuinely existing, non-mock NullInterface class; and
  # then define expectations on it. When we do this, Rspec fails to pass the call on to the object,
  # unless we specifically say `.and_call_original` instead of `.and_return`. 
  #
  # This is actually quite nice, but more than a little confusing when you see it for the first
  # time. Its use isn't spelled out in the RSpec docs AFAICS. 
  #
  # (Also, we define the class inside an Rspec 'let' so that its scope is limited to this test.)
  #
  let(:customer_model_class) do
    Class.new Pod4::Model do
      attr_columns :id, :name, :groups
      attr_columns :price  # specifically testing multiple calls to attr_columns
      set_interface NullInterface.new(:id, :name, :price, :groups, [])

      def map_to_model(ot)
        super
        @groups = @groups ? @groups.split(',') : []
        self
      end

      def map_to_interface
        x = super
        g = (x.>>.groups || []).join(',')
        x.merge(groups: g)
      end

      def fake_an_alert(*args)
        add_alert(*args) #private method
      end

      def validate 
        add_alert(:error, "falling over now") if name == "fall over"
      end

      def reset_alerts; @alerts = []; end
    end
  end

  let(:records) do
    [ {id: 10, name: 'Gomez',     price: 1.23, groups: 'trains'       },
      {id: 20, name: 'Morticia',  price: 2.34, groups: 'spanish'      },
      {id: 30, name: 'Wednesday', price: 3.45, groups: 'school'       },
      {id: 40, name: 'Pugsley',   price: 4.56, groups: 'trains,school'} ]

  end

  let(:recordsx) do
    records.map {|h| h.reject{|k,_| k == :groups} }.flatten
  end

  let(:records_as_ot)  { records.map{|r| Octothorpe.new(r) } }
  let(:recordsx_as_ot) { recordsx.map{|r| Octothorpe.new(r) } }

  def without_groups(ot)
    ot.to_h.reject {|k,_| k == :groups}
  end

  # model is just a plain newly created object that you can call read on.
  # model2 and model3 are in an identical state - they have been filled with a
  # read(). We have two so that we can RSpec 'allow' on one and not the other.

  let(:model) { customer_model_class.new(20) }

  let(:model2) do
    m = customer_model_class.new(30)

    allow( m.interface ).to receive(:read).and_return( Octothorpe.new(records[2]) )
    m.read.or_die
  end

  let(:model3) do
    m = customer_model_class.new(40)

    allow( m.interface ).to receive(:read).and_return( Octothorpe.new(records[3]) )
    m.read.or_die
  end

  # Model4 is for a non-integer id
  let(:thing) { Octothorpe.new(id: 'eek', name: 'thing',  price: 9.99, groups: 'scuttering') }

  let(:model4) do
    m = customer_model_class.new('eek')

    allow( m.interface ).to receive(:read).and_return(thing)
    m.read.or_die
  end

  ##


  describe 'Model.attr_columns' do

    it 'requires a list of columns' do
      expect( customer_model_class ).to respond_to(:attr_columns).with(1).argument
    end

    it 'exposes the columns just like attr_accessor' do
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
  ##


  describe 'Model.columns' do
    it 'lists the columns' do
      expect( customer_model_class.columns ).to match_array( [:id,:name,:price,:groups] )
    end
  end
  ##


  describe 'Model.set_interface' do
    it 'requires an Interface object' do
      expect( customer_model_class ).to respond_to(:set_interface).with(1).argument
    end

    # it 'sets interface' - covered by the interface test
  end
  ##

  
  describe 'Model.interface' do
    it 'is the interface object' do
      expect( customer_model_class.interface ).to be_a_kind_of NullInterface
      expect( customer_model_class.interface.id_fld ).to eq :id
    end
  end
  ##


  describe 'Model.list' do

    let(:list1) { customer_model_class.list }

    def arr_without_groups(arr)
      arr
        .map {|m| without_groups(m.to_ot) }
        .flatten

    end

    it 'allows an optional selection parameter' do
      expect{ customer_model_class.list                }.not_to raise_exception
      expect{ customer_model_class.list(name: 'Betty') }.not_to raise_exception
    end

    it 'returns an array of customer_model_class records' do
      expect( customer_model_class.interface ).
        to receive(:list).with(nil).
        and_return( records_as_ot )

      expect( list1 ).to be_a_kind_of Array
      expect( list1 ).to all(be_a_kind_of customer_model_class)
    end

    it 'returns the data from the interface' do
      expect( customer_model_class.interface ).
        to receive(:list).with(nil).
        and_return(records_as_ot)

      expect( list1.size ).to eq records.size
      expect( arr_without_groups(list1) ).to include( *recordsx )
    end

    it 'honours passed selection criteria' do
      hash = {price: 2.22}

      expect( customer_model_class.interface ).
        to receive(:list).with(hash).
        and_return( [Octothorpe.new(records[1])] )

      list2 = customer_model_class.list(hash)
      expect( list2.size ).to eq 1
      expect( arr_without_groups(list2).first ).to eq( recordsx[1] )
    end

    it 'returns an empty array if nothing matches' do
      hash = {price: 1.23}

      expect( customer_model_class.interface ).
        to receive(:list).with(hash).
        and_return([])

      expect( customer_model_class.list(hash) ).to eq []
    end

    it 'returns an empty array if there are no records' do
      expect( customer_model_class.list ).to eq []
    end

    it 'calls map_to_model to set the record data' do
      allow( customer_model_class.interface ).
        to receive(:list).
        and_return(records_as_ot)

      expect( customer_model_class.list.last.groups ).to eq(['trains', 'school'])
    end

  end
  ##


  describe '#new' do

    it 'takes an optional ID' do
      expect{ customer_model_class.new    }.not_to raise_exception
      expect{ customer_model_class.new(1) }.not_to raise_exception
    end

    it 'sets the ID attribute' do
      expect( customer_model_class.new(23).model_id ).to eq 23
    end

    it 'sets the status to empty' do
      expect( customer_model_class.new.model_status ).to eq :empty
    end

    it 'initializes the alerts attribute' do
      expect( customer_model_class.new.alerts ).to eq([])
    end

    it 'doesn''t freak out if the ID is not an integer' do
      expect{ customer_model_class.new("france") }.not_to raise_exception
      expect( customer_model_class.new("france").model_id ).to eq "france"
    end

  end
  ##


  describe '#interface' do
    it 'returns the interface set in the class definition, again' do
      expect( customer_model_class.new.interface ).to be_a_kind_of NullInterface
      expect( customer_model_class.new.interface.id_fld ).to eq :id
    end
  end
  ##


  describe '#columns' do
    it 'returns the attr_columns list from the class definition' do

      expect( customer_model_class.new.columns ).
        to match_array( [:id,:name,:price,:groups] )

    end
  end
  ##


  describe '#alerts' do
    it 'returns the list of alerts against the model' do
      cm = customer_model_class.new
      cm.fake_an_alert(:warning, :foo, 'one')
      cm.fake_an_alert(:error,   :bar, 'two')

      expect( cm.alerts.size ).to eq 2
      expect( cm.alerts.map{|a| a.message} ).to match_array(%w|one two|)
    end
  end
  ##


  describe '#add_alert' do
    # add_alert is a protected method, which is only supposed to be called
    # within the validate method of a subclass of Method. So we test it by
    # calling our alert faking method

    it 'requires type, message or type, field, message' do
      expect{ model.fake_an_alert        }.to raise_exception ArgumentError
      expect{ model.fake_an_alert(nil)   }.to raise_exception ArgumentError
      expect{ model.fake_an_alert('foo') }.to raise_exception ArgumentError

      expect{ model.fake_an_alert(:error, 'foo') }.not_to raise_exception
      expect{ model.fake_an_alert(:warning, :name, 'bar') }.
        not_to raise_exception

    end

    it 'only allows valid types' do
      [:brian, :werning, nil, :alert, :danger].each do |l|
        expect{ model.fake_an_alert(l, 'foo') }.to raise_exception ArgumentError
      end

      [:warning, :error, :success, :info].each do |l|
        expect{ model.fake_an_alert(l, 'foo') }.not_to raise_exception
      end

    end

    it 'creates an Alert and adds it to @alerts' do
      lurch = 'Dnhhhhhh'
      model.fake_an_alert(:error, :price, lurch)

      expect( model.alerts.size ).to eq 1
      expect( model.alerts.first ).to be_a_kind_of Pod4::Alert
      expect( model.alerts.first.message ).to eq lurch
    end

    it 'sets @model_status if the type is worse than @model_status' do
      model.fake_an_alert(:warning, :price, 'xoo')
      expect( model.model_status ).to eq :warning

      model.fake_an_alert(:success, :price, 'flom')
      expect( model.model_status ).to eq :warning

      model.fake_an_alert(:info, :price, 'flom')
      expect( model.model_status ).to eq :warning

      model.fake_an_alert(:error, :price, 'qar')
      expect( model.model_status ).to eq :error

      model.fake_an_alert(:warning, :price, 'drazq')
      expect( model.model_status ).to eq :error
    end

    it 'ignores a new alert if identical to an existing one' do
      lurch = 'Dnhhhhhh'
      2.times { model.fake_an_alert(:error, :price, lurch) }

      expect( model.alerts.size ).to eq 1
    end

  end
  ##


  describe '#set' do

    let (:ot) { records_as_ot[3] }

    it 'takes an Octothorpe or a Hash' do
      expect{ model.set       }.to raise_exception ArgumentError
      expect{ model.set(nil)  }.to raise_exception ArgumentError
      expect{ model.set(:foo) }.to raise_exception ArgumentError

      expect{ model.set(ot) }.not_to raise_exception 
    end

    it 'returns self' do
      expect( model.set(ot) ).to eq model
    end

    it 'sets the attribute columns from the hash' do
      model.set(ot)

      expect( model.id    ).to eq ot.>>.id
      expect( model.name  ).to eq ot.>>.name
      expect( model.price ).to eq ot.>>.price
    end
    
    it 'only sets the attributes on the model that it is given' do
      otx = Octothorpe.new(name: 'Piggy', price: 98.76, weapon: 'rake')

      expect{ model3.set(otx) }.not_to raise_exception
      expect( model3.id     ).to eq 40
      expect( model3.name   ).to eq 'Piggy'
      expect( model3.price  ).to eq 98.76
      expect( model3.groups ).to eq( ot.>>.groups.split(',') )
    end

  end
  ##


  describe '#to_ot' do
    it 'returns an Octothorpe made of the attribute columns' do
      expect( model.to_ot ).to be_a_kind_of Octothorpe

      expect( model.to_ot.to_h ).
        to eq( {id: nil, name: nil, price:nil, groups:nil} )

      model.map_to_model(records[1])
      expect( model.to_ot ).to be_a_kind_of Octothorpe
      expect( without_groups(model.to_ot) ).to eq recordsx[1]

      model.map_to_model(records_as_ot[2])
      expect( model.to_ot ).to be_a_kind_of Octothorpe
      expect( without_groups(model.to_ot) ).to eq recordsx[2]
    end
  end
  ##


  describe '#map_to_model' do

    it 'sets the columns, with groups as an array' do
      cm = customer_model_class.new
      cm.map_to_model(records.last)

      expect( cm.groups ).to eq( ['trains','school'] )
    end

  end
  ##


  describe '#map_to_interface' do

    it 'returns the columns, with groups as a list' do
      cm = customer_model_class.new
      cm.map_to_model(records.last)

      expect( cm.map_to_interface.>>.groups ).to eq( 'trains,school' )
    end

  end
  ##


  describe '#raise_exceptions' do

    it 'is also known as .or_die' do
      cm = customer_model_class.new
      expect( cm.method(:raise_exceptions) ).to eq( cm.method(:or_die) )
    end

    it 'raises ValidationError if model status is :error' do
      model.fake_an_alert(:error, :price, 'qar')
      expect{ model.raise_exceptions }.to raise_exception Pod4::ValidationError
    end

    it 'does nothing if model status is not :error' do
      expect{ model.raise_exceptions }.not_to raise_exception

      model.fake_an_alert(:info, :price, 'qar')
      expect{ model.raise_exceptions }.not_to raise_exception

      model.fake_an_alert(:success, :price, 'qar')
      expect{ model.raise_exceptions }.not_to raise_exception

      model.fake_an_alert(:warning, :price, 'qar')
      expect{ model.raise_exceptions }.not_to raise_exception
    end

  end
  ##


  describe '#create' do

    let (:new_model) { customer_model_class.new }

    it 'takes no parameters' do
      expect{ customer_model_class.new.create(12) }.to raise_exception ArgumentError
      expect{ customer_model_class.new.create     }.not_to raise_exception
    end

    it 'returns self' do
      expect( new_model.create ).to eq new_model
    end

    it 'calls validate' do
      # validation tests arity of the validate method; rspec freaks out. So we can't 
      # `expect( new_model ).to receive(:validate)`

      m = customer_model_class.new
      m.name = "fall over"
      m.create
      expect( m.model_status ).to eq :error
    end

    it 'calls create on the interface if the record is good' do
      expect( customer_model_class.interface ).to receive(:create)
      customer_model_class.new.create

      new_model.fake_an_alert(:warning, :name, 'foo')
      expect( new_model.interface ).to receive(:create)
      new_model.create
    end


    it 'doesnt call create on the interface if the record is bad' do
      new_model.fake_an_alert(:error, :name, 'foo')
      expect( new_model.interface ).not_to receive(:create)
      new_model.create
    end

    it 'sets the ID' do
      new_model.id   = 50
      new_model.name = "Lurch"
      new_model.create

      expect( new_model.model_id ).to eq 50
    end

    it 'sets model status to :okay if it was :empty' do
      new_model.id   = 50
      new_model.name = "Lurch"
      new_model.create

      expect( new_model.model_status ).to eq :okay
    end

    it 'leaves the model status alone if it was not :empty' do
      new_model.id   = 50
      new_model.name = "Lurch"
      new_model.create

      new_model.fake_an_alert(:warning, :price, 'qar')
      expect( new_model.model_status ).to eq :warning
    end

    it 'calls map_to_interface to get record data' do
      allow( new_model.interface ).to receive(:create)
      expect( new_model ).to receive(:map_to_interface)

      new_model.id   = 50
      new_model.name = "Lurch"
      new_model.create
    end

    it 'doesn\'t freak out if the model is not an integer' do
      expect( new_model.interface ).to receive(:create)
      new_model.id   = "handy"
      new_model.name = "Thing"

      expect{ new_model.create }.not_to raise_error
    end

    it "creates an alert instead when the interface raises WeakError" do
      allow( new_model.interface ).to receive(:create).and_raise Pod4::WeakError, "foo"

      new_model.id   = 50
      new_model.name = "Lurch"
      expect{ new_model.create }.not_to raise_exception
      expect( new_model.model_status ).to eq :error
      expect( new_model.alerts.map(&:message) ).to include( include "foo" )
    end

  end
  ##


  describe '#read' do

    it 'takes no parameters' do
      expect{ customer_model_class.new.create(12) }.to raise_exception ArgumentError
      expect{ customer_model_class.new.create     }.not_to raise_exception
    end

    it 'returns self ' do
      allow( model.interface ).
        to receive(:read).
        and_return( records_as_ot.first )

      expect( model.read ).to eq model
    end

    it 'calls read on the interface' do
      expect( model.interface ).
        to receive(:read).
        and_return( records_as_ot.first )

      model.read
    end

    it 'calls validate' do
      # again, because rspec is a bit stupid, we can't just `expect(model).to receive(:validate)`

      allow( model.interface ).
        to receive(:read).
        and_return( records_as_ot.first.merge(name: "fall over") )

      model.read
      expect( model.model_status ).to eq :error
    end

    it 'sets the attribute columns using map_to_model' do
      ot = records_as_ot.last
      allow( model.interface ).to receive(:read).and_return( ot )

      cm = customer_model_class.new(10).read
      expect( cm.id    ).to eq ot.>>.id
      expect( cm.name  ).to eq ot.>>.name
      expect( cm.price ).to eq ot.>>.price
      expect( cm.groups ).to be_a_kind_of(Array)
      expect( cm.groups ).to eq( ot.>>.groups.split(',') )
    end

    it 'sets model status to :okay if it was :empty' do
      ot = records_as_ot.last
      allow( model.interface ).to receive(:read).and_return( ot )

      model.read
      expect( model.model_status ).to eq :okay
    end

    it 'leaves the model status alone if it was not :empty' do
      ot = records_as_ot.last
      allow( model.interface ).to receive(:read).and_return( ot )

      model.fake_an_alert(:warning, :price, 'qar')
      model.read
      expect( model.model_status ).to eq :warning
    end

    it 'doesn\'t freak out if the model is non-integer' do
      allow( model.interface ).to receive(:read).and_return( thing )

      expect{ customer_model_class.new('eek').read }.not_to raise_error
    end

    context 'if the interface.read returns an empty Octothorpe' do
      let(:missing) { customer_model_class.new(99) }

      it 'doesn\'t throw an exception' do
        expect{ missing.read }.not_to raise_exception
      end

      it 'raises an error alert' do
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

  end
  ##


  describe '#update' do

    before do
      allow( model2.interface ).
        to receive(:update).
        and_return( model2.interface )

    end

    it 'takes no parameters' do
      expect{ model2.update(12) }.to raise_exception ArgumentError
      expect{ model2.update     }.not_to raise_exception
    end

    it 'returns self' do
      expect( model2.update ).to eq model2
    end

    it 'raises a Pod4Error if model status is :empty' do
      allow( model.interface ).to receive(:update).and_return( model.interface )

      expect( model.model_status ).to eq :empty
      expect{ model.update }.to raise_exception Pod4::Pod4Error
    end

    it 'raises a Pod4Error if model status is :deleted' do
      model2.delete
      expect{ model2.update }.to raise_exception Pod4::Pod4Error
    end

    it 'calls validate' do
      # again, we can't `expect(model2).to receive(:validate)` because we're testing arity there
      model2.name = "fall over"
      model2.update
      expect( model2.model_status ).to eq :error
    end

    it 'calls update on the interface if the validation passes' do
      expect( model3.interface ).
        to receive(:update).
        and_return( model3.interface )

      model3.update
    end

    it 'doesn\'t call update on the interface if the validation fails' do
      expect( model3.interface ).not_to receive(:update)

      model3.name = "fall over"  # triggers validation
      model3.update
    end

    it 'calls map_to_interface to get record data' do
      expect( model3 ).to receive(:map_to_interface)
      model3.update
    end

    it 'doesn\'t freak out if the model is non-integer' do
      expect( model4.interface ).
        to receive(:update).
        and_return( model4.interface )

      model4.update
    end

    context 'when the record already has error alerts' do

      it 'passes if there is no longer anything wrong' do
        expect( model3.interface ).
          to receive(:update).
          and_return( model3.interface )

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

  end
  ##


  describe '#delete' do

    before do
      allow( model2.interface ).
        to receive(:delete).
        and_return( model2.interface )

    end

    it 'takes no parameters' do
      expect{ model2.delete(12) }.to raise_exception ArgumentError
      expect{ model2.delete     }.not_to raise_exception
    end

    it 'returns self' do
      expect( model2.delete ).to eq model2
    end

    it 'raises a Pod4Error if model status is :empty' do
      allow( model.interface ).to receive(:delete).and_return( model.interface )

      expect( model.model_status ).to eq :empty
      expect{ model.delete }.to raise_exception Pod4::Pod4Error
    end

    it 'raises a Pod4Error if model status is :deleted'do
      model2.delete
      expect{ model2.delete }.to raise_exception Pod4::Pod4Error
    end

    it 'calls validate' do
      # again, because rspec can't cope with us testing arity in Pod4::Model, we can't say
      # `expect(model2).to receive(:validate)`. But for delete we are only running validation as a
      # courtesy -- a validation fail does not stop the delete, it just sets alerts. So the model
      # status should be :deleted and not :error
      model2.name = "fall over"
      model2.delete

      # one of the elements of the alerts array should include the word "falling"
      expect( model2.alerts.map(&:message) ).to include(include "falling")
    end

    it 'calls delete on the interface if the model status is good' do
      expect( model3.interface ).
        to receive(:delete).
        and_return( model3.interface )

      model3.delete 
    end

    it 'calls delete on the interface if the model status is bad' do
      expect( model3.interface ).
        to receive(:delete).
        and_return( model3.interface )

      model3.fake_an_alert(:error, :price, 'qar')
      model3.delete 
    end

    it 'still gives you full access to the data after a delete' do
      model2.delete

      expect( model2.id    ).to eq records_as_ot[2].>>.id
      expect( model2.name  ).to eq records_as_ot[2].>>.name
      expect( model2.price ).to eq records_as_ot[2].>>.price
    end

    it 'sets status to :deleted' do
      model2.delete
      expect( model2.model_status ).to eq :deleted
    end

    it 'doesn\'t freak out if the model is non-integer' do
      expect( model4.interface ).
        to receive(:delete).
        and_return( model4.interface )

      model4.delete
    end

    it "creates an alert instead when the interface raises WeakError" do
      allow( model3.interface ).to receive(:delete).and_raise Pod4::WeakError, "foo"

      expect{ model3.delete }.not_to raise_exception
      expect( model3.alerts.map(&:message) ).to include( include "foo" )
    end

  end
  ##

end

