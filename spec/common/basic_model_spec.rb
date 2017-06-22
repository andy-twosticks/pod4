require 'octothorpe'

require 'pod4/basic_model'
require 'pod4/null_interface'


describe 'WeirdModel' do

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
  let(:weird_model_class) do
    Class.new Pod4::BasicModel do
      set_interface NullInterface.new(:id, :name, :price, :groups, [])

      def fake_an_alert(*args)
        add_alert(*args) #protected method
      end

      def reset_alerts; @alerts = []; end
    end
  end

  let(:model) { weird_model_class.new(20) }


  describe 'Model.set_interface' do
    it 'requires an Interface object' do
      expect( weird_model_class ).to respond_to(:set_interface).with(1).argument
    end

    # it 'sets interface' - covered by the interface test
  end
  ##

  
  describe 'Model.interface' do
    it 'is the interface object' do
      expect( weird_model_class.interface ).to be_a_kind_of NullInterface
      expect( weird_model_class.interface.id_fld ).to eq :id
    end
  end
  ##


  describe '#new' do

    it 'takes an optional ID' do
      expect{ weird_model_class.new    }.not_to raise_exception
      expect{ weird_model_class.new(1) }.not_to raise_exception
    end

    it 'sets the ID attribute' do
      expect( weird_model_class.new(23).model_id ).to eq 23
    end

    it 'sets the status to empty' do
      expect( weird_model_class.new.model_status ).to eq :empty
    end

    it 'initializes the alerts attribute' do
      expect( weird_model_class.new.alerts ).to eq([])
    end

    it 'doesn''t freak out if the ID is not an integer' do
      expect{ weird_model_class.new("france") }.not_to raise_exception
      expect( weird_model_class.new("france").model_id ).to eq "france"
    end

  end
  ##


  describe '#interface' do
    it 'returns the interface set in the class definition, again' do
      expect( weird_model_class.new.interface ).to be_a_kind_of NullInterface
      expect( weird_model_class.new.interface.id_fld ).to eq :id
    end
  end
  ##


  describe '#alerts' do
    it 'returns the list of alerts against the model' do
      cm = weird_model_class.new
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

      expect( model.alerts.size ).to eq 2
    end

  end
  ##


  describe '#clear_alerts' do
    before do
      model.fake_an_alert(:error, "bad stuff")
      model.clear_alerts
    end

    it 'resets the @alerts array' do
      expect( model.alerts ).to eq([])
    end

    it 'sets model_status to :okay' do
      expect( model.model_status ).to eq :okay
    end


  end
  ##


  describe '#raise_exceptions' do

    it 'is also known as .or_die' do
      cm = weird_model_class.new
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


end

