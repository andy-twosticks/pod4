require 'octothorpe'

require 'pod4/model'
require 'pod4/null_interface'


##
# We define a model class to test, since in normal operation we would never use
# Model directly, and since it needs an inner Interface.
#
# We can't use a mock for the interface -- class definitions fall outside the
# RSpec DSL as far as I can tell, so I can neither create a mock here or inject
# it. Which means we can't mock the interface in the rest of the test either;
# any mock we created would not get called.
#
# But: we want to test that Model calls Interface correctly.
#
# We do have what appears to be a perfectly sane way of testing. We can define
# an inner class based on the genuinely existing, non-mock NullInterface class;
# and then define expectations on it. When we do this, Rspec fails to pass the
# call on to the object, unless we specifically say `.and_call_original`
# instead of `.and_return`. 
#
# This is actually quite nice, but more than a little confusing when you see it
# for the first time. Its use isn't spelled out in the RSpec docs AFAICS. 
#
class CustomerModel < Pod4::Model
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
    add_alert(*args) #protected method
  end

  def reset_alerts; @alerts = []; end
end



describe 'CustomerModel' do

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

  let(:model) { CustomerModel.new(20) }

  let(:model2) do
    m = CustomerModel.new(30)

    allow( m.interface ).to receive(:read).
      and_return( Octothorpe.new(records[2]) )

    m.read.or_die
  end

  let(:model3) do
    m = CustomerModel.new(40)

    allow( m.interface ).to receive(:read).
      and_return( Octothorpe.new(records[3]) )

    m.read.or_die
  end


  ##


  describe 'Model.attr_columns' do

    it 'requires a list of columns' do
      expect( CustomerModel ).to respond_to(:attr_columns).with(1).argument
    end

    it 'exposes the columns just like attr_accessor' do
      expect( CustomerModel.new ).to respond_to(:id)
      expect( CustomerModel.new ).to respond_to(:name)
      expect( CustomerModel.new ).to respond_to(:price)
      expect( CustomerModel.new ).to respond_to(:groups)
      expect( CustomerModel.new ).to respond_to(:id=)
      expect( CustomerModel.new ).to respond_to(:name=)
      expect( CustomerModel.new ).to respond_to(:price=)
      expect( CustomerModel.new ).to respond_to(:groups=)
    end

    # it adds the columns to Model.columns -- covered by the columns test
  end
  ##


  describe 'Model.columns' do
    it 'lists the columns' do
      expect( CustomerModel.columns ).to match_array( [:id,:name,:price,:groups] )
    end
  end
  ##


  describe 'Model.set_interface' do
    it 'requires an Interface object' do
      expect( CustomerModel ).to respond_to(:set_interface).with(1).argument
    end

    # it 'sets interface' - covered by the interface test
  end
  ##

  
  describe 'Model.interface' do
    it 'is the interface object' do
      expect( CustomerModel.interface ).to be_a_kind_of NullInterface
      expect( CustomerModel.interface.id_fld ).to eq :id
    end
  end
  ##


  describe 'Model.list' do

    let(:list1) { CustomerModel.list }

    def arr_without_groups(arr)
      arr
        .map {|m| without_groups(m.to_ot) }
        .flatten

    end

    it 'allows an optional selection parameter' do
      expect{ CustomerModel.list                }.not_to raise_exception
      expect{ CustomerModel.list(name: 'Betty') }.not_to raise_exception
    end

    it 'returns an array of CustomerModel records' do
      expect( CustomerModel.interface ).
        to receive(:list).with(nil).
        and_return( records_as_ot )

      expect( list1 ).to be_a_kind_of Array
      expect( list1 ).to all(be_a_kind_of CustomerModel)
    end

    it 'returns the data from the interface' do
      expect( CustomerModel.interface ).
        to receive(:list).with(nil).
        and_return(records_as_ot)

      expect( list1.size ).to eq records.size
      expect( arr_without_groups(list1) ).to include( *recordsx )
    end

    it 'honours passed selection criteria' do
      hash = {price: 2.22}

      expect( CustomerModel.interface ).
        to receive(:list).with(hash).
        and_return( [Octothorpe.new(records[1])] )

      list2 = CustomerModel.list(hash)
      expect( list2.size ).to eq 1
      expect( arr_without_groups(list2).first ).to eq( recordsx[1] )
    end

    it 'returns an empty array if nothing matches' do
      hash = {price: 1.23}

      expect( CustomerModel.interface ).
        to receive(:list).with(hash).
        and_return([])

      expect( CustomerModel.list(hash) ).to eq []
    end

    it 'returns an empty array if there are no records' do
      expect( CustomerModel.list ).to eq []
    end

    it 'calls map_to_model to set the record data' do
      allow( CustomerModel.interface ).
        to receive(:list).
        and_return(records_as_ot)

      expect( CustomerModel.list.last.groups ).to eq(['trains', 'school'])
    end

  end
  ##


  describe '#new' do

    it 'takes an optional ID' do
      expect{ CustomerModel.new    }.not_to raise_exception
      expect{ CustomerModel.new(1) }.not_to raise_exception
    end

    it 'sets the ID attribute' do
      expect( CustomerModel.new(23).model_id ).to eq 23
    end

    it 'sets the status to empty' do
      expect( CustomerModel.new.model_status ).to eq :empty
    end

    it 'initializes the alerts attribute' do
      expect( CustomerModel.new.alerts ).to eq([])
    end

  end
  ##


  describe '#interface' do
    it 'returns the interface set in the class definition, again' do
      expect( CustomerModel.new.interface ).to be_a_kind_of NullInterface
      expect( CustomerModel.new.interface.id_fld ).to eq :id
    end
  end
  ##


  describe '#columns' do
    it 'returns the attr_columns list from the class definition' do

      expect( CustomerModel.new.columns ).
        to match_array( [:id,:name,:price,:groups] )

    end
  end
  ##


  describe '#alerts' do
    it 'returns the list of alerts against the model' do
      cm = CustomerModel.new
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


  describe '#validate' do
    it 'takes no parameters' do
      expect{ CustomerModel.new.validate(12) }.to raise_exception ArgumentError
      expect{ CustomerModel.new.validate     }.not_to raise_exception
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
    
    it 'runs validate' do
      expect( model ).to receive(:validate)
      model.set(ot)
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
      cm = CustomerModel.new
      cm.map_to_model(records.last)

      expect( cm.groups ).to eq( ['trains','school'] )
    end

  end
  ##


  describe '#map_to_interface' do

    it 'returns the columns, with groups as a list' do
      cm = CustomerModel.new
      cm.map_to_model(records.last)

      expect( cm.map_to_interface.>>.groups ).to eq( 'trains,school' )
    end

  end
  ##


  describe '#raise_exceptions' do

    it 'is also known as .or_die' do
      cm = CustomerModel.new
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

    let (:new_model) { CustomerModel.new }

    it 'takes no parameters' do
      expect{ CustomerModel.new.create(12) }.to raise_exception ArgumentError
      expect{ CustomerModel.new.create     }.not_to raise_exception
    end

    it 'returns self' do
      expect( new_model.create ).to eq new_model
    end

    it 'calls validate' do
      expect( new_model ).to receive(:validate)
      new_model.create
    end

    it 'calls create on the interface if the record is good' do
      expect( CustomerModel.interface ).to receive(:create)
      CustomerModel.new.create

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

  end
  ##


  describe '#read' do

    it 'takes no parameters' do
      expect{ CustomerModel.new.create(12) }.to raise_exception ArgumentError
      expect{ CustomerModel.new.create     }.not_to raise_exception
    end

    it 'returns self ' do
      allow( model.interface ).
        to receive(:read).
        and_return( records_as_ot.first )

      expect( model.read ).to eq model
    end

    it 'calls read on the interface' do
      # calls set, allegedly, but we don't 'know' that
      expect( model.interface ).
        to receive(:read).
        and_return( records_as_ot.first )

      model.read
    end

    it 'calls validate' do
      allow( model.interface ).
        to receive(:read).
        and_return( records_as_ot.first )

      expect( model ).to receive(:validate)
      model.read
    end

    it 'sets the attribute columns using map_to_model' do
      ot = records_as_ot.last
      allow( model.interface ).to receive(:read).and_return( ot )

      cm = CustomerModel.new(10).read
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
      expect( model2 ).to receive(:validate)
      model2.update
    end

    it 'calls update on the interface if the validation passes' do
      expect( model3.interface ).
        to receive(:update).
        and_return( model3.interface )

      model3.update
    end

    it 'doesnt call update on the interface if the validation fails' do
      expect( model3.interface ).not_to receive(:update)

      model3.fake_an_alert(:error, :price, 'qar')
      model3.update
    end

    it 'calls map_to_interface to get record data' do
      expect( model3 ).to receive(:map_to_interface)
      model3.update
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
      expect( model2 ).to receive(:validate)
      model2.delete
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

  end
  ##

end

