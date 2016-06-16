require 'octothorpe'

require 'pod4'
require 'pod4/typecasting'
require 'pod4/null_interface'


class ProductModel < Pod4::Model
  include Pod4::TypeCasting
  force_encoding Encoding::ISO_8859_1   # I assume we are running as UTF8 here
  attr_columns :id, :code, :product, :price
  set_interface NullInterface.new(:id, :code, :product, :price, [])
end



describe 'ProductModel' do

  let(:records) do
    [ {id: 10, code: 'aa1', product: 'beans',   price: 1.23},
      {id: 20, code: 'bb1', product: 'pears',   price: 2.34},
      {id: 30, code: 'cc1', product: 'soap',    price: 3.45},
      {id: 40, code: 'cc2', product: 'matches', price: 4.56} ]
  end

  let(:model) { ProductModel.new(20) }

  let(:model2) do
    m = ProductModel.new(30)

    allow( m.interface ).to receive(:read).
      and_return( Octothorpe.new(records[2]) )

    m.read.or_die
  end

  let(:records_as_ot)  { records.map{|r| Octothorpe.new(r) } }


  ###


  describe 'Model.force_encoding' do

    it 'requires an encoding' do
      expect( ProductModel ).to respond_to(:force_encoding).with(1).argument

      expect{ ProductModel.force_encoding('foo') }.to raise_exception Pod4Error

      # Cheating here: this has to be the same as above or other tests will
      # fail...
      expect{ ProductModel.force_encoding(Encoding::ISO_8859_1) }.
        not_to raise_exception

    end

    it 'sets the encoding to be returned by Model.encoding' do
      expect{ ProductModel.encoding }.not_to raise_exception
      expect( ProductModel.encoding ).to eq(Encoding::ISO_8859_1)
    end

  end
  ##
  

  describe '#map_to_model' do

    it 'forces each string to map to the given encoding' do
      # map_to_model has already happened at this point. No matter.
      ot = model2.to_ot
      expect( ot.>>.id ).to eq 30
      expect( ot.>>.price ).to eq 3.45
      expect( ot.>>.code.encoding ).to eq Encoding::ISO_8859_1
      expect( ot.>>.product.encoding ).to eq Encoding::ISO_8859_1
    end

  end



end

