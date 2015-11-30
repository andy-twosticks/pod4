require 'pod4/param'


describe Param do

  after do
    Param.reset
  end

  ##


  describe 'Param.set' do
   
    it 'requires a parameter and a value' do
      # We're not fussed about much validation since this is internal
      expect{ Param.set       }.to raise_exception ArgumentError
      expect{ Param.set(:foo) }.to raise_exception ArgumentError

      expect{ Param.set(:foo, 'bar') }.not_to raise_exception
    end

    it 'sets a parameter to a value' do
      Param.set(:foo, 'bar')
      expect( Param.params ).to include({foo: 'bar'})
    end

  end
  ##


  describe 'Param.get' do

    it 'requires a parameter name' do
      # We're not fussed about much validation since this is internal
      expect{ Param.get       }.to raise_exception ArgumentError
      expect{ Param.get(:foo) }.not_to raise_exception
    end

    it 'returns a parameter value' do
      Param.set(:foo, 'bar')
      expect( Param.get(:foo) ).to eq 'bar'
    end

    it 'returns nil if the parameter was not set' do
      expect( Param.get(:baz) ).to eq nil
    end

  end
  ##


  describe 'Param.reset' do

    it 'removes all parameters' do
      # probably only this test program needs this method
      Param.set(:ermintrude, 'darling')
      Param.reset
      expect( Param.params ).to eq({})
    end

  end
  ##


  describe 'param.get_all' do

    it 'returns all the parameters as an Octothorpe' do
      Param.set(:ermintrude, 'darling')
      Param.set(:dillon,     'zzz')
      Param.set(:zebedee,    'time for bed')

      expect( Param.get_all ).to be_a_kind_of Octothorpe
      expect( Param.get_all.to_h ).to include( ermintrude: 'darling',
                                               dillon:     'zzz',
                                               zebedee:    'time for bed' )

    end

    it 'still returns an Octothorpe if no parameters were set' do
      expect( Param.get_all ).to be_a_kind_of Octothorpe
      expect( Param.get_all.to_h ).to eq({})
    end

  end
  ##

end

