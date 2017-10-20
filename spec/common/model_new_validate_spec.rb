require 'octothorpe'

require 'pod4/model'
require 'pod4/null_interface'


##
# This is purely here to test that model works when you have a validate that accepts the new
# vmode parameter
#
describe 'Customer Model with new validate' do

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

      def validate(vmode)
        add_alert(:error, "falling over for mode #{vmode}") if name == "fall over"
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

  let(:records_as_ot)  { records.map{|r| Octothorpe.new(r) } }

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

  ##


  describe '#create' do

    let (:new_model) { customer_model_class.new }

    it 'calls validate and passes the parameter' do
      # validation tests arity of the validate method; rspec freaks out. So we can't 
      # `expect( new_model ).to receive(:validate)`

      m = customer_model_class.new
      m.name = "fall over"
      m.create
      expect( m.model_status ).to eq :error
      expect( m.alerts.map(&:message) ).to include( include "create" )
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

  end
  ##


  describe '#read' do

    it 'calls validate and passes the parameter' do
      # again, because rspec is a bit stupid, we can't just `expect(model).to receive(:validate)`

      allow( model.interface ).
        to receive(:read).
        and_return( records_as_ot.first.merge(name: "fall over") )

      model.read
      expect( model.model_status ).to eq :error
      expect( model.alerts.map(&:message) ).to include( include "mode read" )
    end

  end
  ##


  describe '#update' do

    before do
      allow( model2.interface ).
        to receive(:update).
        and_return( model2.interface )

    end

    it 'calls validate and passes the parameter' do
      # again, we can't `expect(model2).to receive(:validate)` because we're testing arity there
      model2.name = "fall over"
      model2.update
      expect( model2.model_status ).to eq :error
      expect( model2.alerts.map(&:message) ).to include( include "mode update" )
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

  end
  ##


  describe '#delete' do

    before do
      allow( model2.interface ).
        to receive(:delete).
        and_return( model2.interface )

    end

    it 'calls validate and passes the parameter' do
      # again, because rspec can't cope with us testing arity in Pod4::Model, we can't say
      # `expect(model2).to receive(:validate)`. But for delete we are only running validation as a
      # courtesy -- a validation fail does not stop the delete, it just sets alerts. So the model
      # status should be :deleted and not :error
      model2.name = "fall over"
      model2.delete
      expect( model2.alerts.map(&:message) ).to include(include "mode delete")
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

  end
  ##

end

