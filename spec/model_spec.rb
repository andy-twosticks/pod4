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
  attr_columns :id, :name, :price
  set_interface NullInterface.new(:id, :name, :price, [])

  def fake_an_alert(*args)
    add_alert(*args) #protected method
  end

  def reset_alerts; @alerts = []; end
end



describe 'CustomerModel' do

  let(:records) do
    [ {id: 10, name: 'Gomez',     price: 1.23},
      {id: 20, name: 'Morticia',  price: 2.34},
      {id: 30, name: 'Wednesday', price: 3.45},
      {id: 40, name: 'Pugsley',   price: 4.56} ]
  end

  let(:records_as_ot) { records.map{|r| Octothorpe.new(r) } }

  let(:model) { CustomerModel.new(20) }

  ##


  describe 'Model.attr_columns' do

    it 'requires a list of columns' do
      expect( CustomerModel ).to respond_to(:attr_columns).with(1).argument
    end

    it 'exposes the columns just like attr_accessor' do
      expect( CustomerModel.new ).to respond_to(:id)
      expect( CustomerModel.new ).to respond_to(:name)
      expect( CustomerModel.new ).to respond_to(:price)
      expect( CustomerModel.new ).to respond_to(:id=)
      expect( CustomerModel.new ).to respond_to(:name=)
      expect( CustomerModel.new ).to respond_to(:price=)
    end

    # it adds the columns to Model.columns -- covered by the columns test
  end
  ##


  describe 'Model.columns' do
    it 'lists the columns' do
      expect( CustomerModel.columns ).to match_array( [:id,:name,:price] )
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
      expect( list1.map{|x| x.to_ot.to_h} ).to match_array records
    end

    it 'honours passed selection criteria' do
      hash = {price: 2.22}

      expect( CustomerModel.interface ).
        to receive(:list).with(hash).
        and_return( [Octothorpe.new(records[1])] )

      list2 = CustomerModel.list(hash)
      expect( list2.size ).to eq 1
      expect( list2.first.to_ot.to_h ).to eq( records[1] )
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
      expect( CustomerModel.new.columns ).to match_array([:id,:name,:price])
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
      expect( model.to_ot.to_h ).to eq({id: nil, name: nil, price:nil})

      model.set(records[1])
      expect( model.to_ot ).to be_a_kind_of Octothorpe
      expect( model.to_ot.to_h ).to eq records[1]

      model.set(records_as_ot[2])
      expect( model.to_ot ).to be_a_kind_of Octothorpe
      expect( model.to_ot.to_h ).to eq records[2]
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

    it 'sets the attribute columns' do
      ot = records_as_ot.last
      allow( model.interface ).to receive(:read).and_return( ot )

      cm = CustomerModel.new(10).read
      expect( cm.id    ).to eq ot.>>.id
      expect( cm.name  ).to eq ot.>>.name
      expect( cm.price ).to eq ot.>>.price
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

    it 'takes no parameters' do
      allow( model.interface ).to receive(:update).and_return( model.interface )
      expect{ model.update(12) }.to raise_exception ArgumentError
      expect{ model.update     }.not_to raise_exception
    end

    it 'returns self' do
      allow( model.interface ).to receive(:update).and_return( model.interface )
      expect( model.create ).to eq model
    end

    it 'raises a Pod4Error if model status is :empty' do
      allow( model.interface ).to receive(:update).and_return( model.interface )
      expect{ model.update }.to raise_exception Pod4::Pod4Error
    end

    it 'raises a Pod4Error if model status is :deleted'

    it 'calls validate' do
      allow( model.interface ).to receive(:update).and_return( model.interface )
      expect( model ).to receive(:validate)
      model.update
    end

    it 'calls update on the interface if the validation passes' do
      expect( model.interface ).
        to receive(:update).
        and_return( model.interface )

      model.update
    end

    it 'doesnt call update on the interface if the validation fails' do
      expect( model.interface ).not_to receive(:update)

      model.fake_an_alert(:error, :price, 'qar')
      model.update
    end

  end
  ##


  describe '#delete' do

    it 'takes no parameters' do
      allow( model.interface ).to receive(:delete).and_return( model.interface )
      expect{ model.delete(12) }.to raise_exception ArgumentError
      expect{ model.delete     }.not_to raise_exception
    end

    it 'returns self' do
      allow( model.interface ).to receive(:delete).and_return( model.interface )
      expect( model.delete ).to eq model
    end

    it 'raises a Pod4Error if model status is :empty'

    it 'raises a Pod4Error if model status is :deleted'

    it 'calls validate' do
      allow( model.interface ).to receive(:delete).and_return( model.interface )
      expect( model ).to receive(:validate)
      model.delete
    end

    it 'calls delete on the interface if the model status is good' do
      expect( model.interface ).
        to receive(:delete).
        and_return( model.interface )

      model.delete 
    end

    it 'calls delete on the interface if the model status is bad' do
      expect( model.interface ).
        to receive(:delete).
        and_return( model.interface )

      model.fake_an_alert(:error, :price, 'qar')
      model.delete 
    end

    it 'still gives you full access to the data after a delete' do
      allow( model.interface ).to receive(:delete).and_return( model.interface )

      ot = records_as_ot.last
      cm = CustomerModel.new(40)
      cm.set(ot)
      cm.delete

      expect( cm.id    ).to eq ot.>>.id
      expect( cm.name  ).to eq ot.>>.name
      expect( cm.price ).to eq ot.>>.price
    end

    it 'sets status to :deleted' do
      allow( model.interface ).to receive(:delete).and_return( model.interface )
      model.delete
      expect( model.model_status ).to eq :deleted
    end

  end
  ##

end

