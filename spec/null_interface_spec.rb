require 'pod4/null_interface'


describe NullInterface do

  let(:data) do
    [ {name: 'Barney', price: 1.11},
      {name: 'Fred',   price: 2.22},
      {name: 'Betty',  price: 3.33} ]
  end

  let (:interface) { NullInterface.new(:name, :price, data) }

  ##


  describe '#new' do

    it 'requires a list of columns and an array of hashes' do
      expect{ NullInterface.new        }.to raise_exception ArgumentError
      expect{ NullInterface.new(nil)   }.to raise_exception ArgumentError
      expect{ NullInterface.new('foo') }.to raise_exception ArgumentError

      expect{ NullInterface.new(:one, [{one:1}]) }.not_to raise_exception
    end

  end
  ##


  describe '#create' do

    let(:hash) { {name: 'Bam-Bam', price: 4.44} }
    let(:ot)   { Octothorpe.new(name: 'Wilma', price: 5.55) }

    it 'requires a hash or an OT' do
      expect{ interface.create      }.to raise_exception ArgumentError
      expect{ interface.create(nil) }.to raise_exception ArgumentError
      expect{ interface.create(3)   }.to raise_exception ArgumentError

      expect{ interface.create(hash) }.not_to raise_exception
      expect{ interface.create(ot)   }.not_to raise_exception
    end

    it 'creates the record and returns the id when given a hash' do
      id = interface.create(hash)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include hash
    end

    it 'creates the record and returns the id when given an Octothorpe' do
      id = interface.create(ot)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include ot.to_h
    end

  end
  ##


  describe '#read' do

    it 'requires an id' do
      expect{ interface.read      }.to raise_exception ArgumentError
      expect{ interface.read(nil) }.to raise_exception ArgumentError

      expect{ interface.read('Barney') }.not_to raise_exception
    end

    it 'returns the record for the id as an Octothorpe' do
      expect( interface.read('Barney')      ).to be_a_kind_of Octothorpe
      expect( interface.read('Fred').to_h ).to include(name: 'Fred', price: 2.22)
    end

    it 'raises a Pod4::DatabaseError if anything goes wrong' do
      expect{ interface.read(:foo) }.to raise_exception DatabaseError
    end

  end
  ##



  describe '#list' do

    it 'has an optional selection parameter, a hash' do
      expect{ interface.list }.not_to raise_exception
      expect{ interface.list(name: 'Barney') }.not_to raise_exception
    end

    it 'returns an array of Octothorpes that match the records' do
      arr = interface.list.map(&:to_h)
      expect( arr ).to match_array data
    end

    it 'returns a subset of records based on the selection parameter' do
      expect( interface.list(name: 'Fred').size ).to eq 1

      expect( interface.list(name: 'Betty').first.to_h ).
        to include(name: 'Betty', price: 3.33)

    end

    it 'returns an empty Array if nothing matches' do
      expect( interface.list(name: 'Yogi') ).to eq([])
    end

    it 'returns an empty Array if there is no data' do
      # remove all the data
      interface.list.
        map {|x| x.>>.name }.
        each {|y| interface.delete(y) }

      expect( interface.list ).to eq([])
    end

  end
  ##
  

  describe '#update' do

    let(:id) { interface.list.first[:name] }

    it 'requires an id and a record (hash or OT)' do
      expect{ interface.update      }.to raise_exception ArgumentError
      expect{ interface.update(nil) }.to raise_exception ArgumentError
      expect{ interface.update(14)  }.to raise_exception ArgumentError
    end

    it 'updates the record at ID with record parameter' do
      record = {price: 99.99}
      interface.update(id, record)

      expect( interface.read(id).to_h ).to include(record)
    end

    it 'returns self' do
      expect( interface.update(id, name: 'frank') ).to eq interface
    end

  end
  ##


  describe '#delete' do

    let(:id) { interface.list.last[:name] }

    it 'requires an id' do
      expect{ interface.delete      }.to raise_exception ArgumentError
      expect{ interface.delete(nil) }.to raise_exception ArgumentError
    end

    it 'makes the record at ID go away' do
      interface.delete(id)

      expect( interface.list.size ).to eq(data.size - 1)
      expect( interface.list.map{|r| r[:name] } ).not_to include 'Betty'
    end

    it 'returns self' do
      expect( interface.delete(id) ).to eq interface
    end

    it 'raises DatabaseError if anything hinky happens' do
      expect{ interface.delete(:foo) }.to raise_exception DatabaseError
      expect{ interface.delete(99)   }.to raise_exception DatabaseError
    end

  end
  ##


end

