require 'octothorpe'


RSpec.shared_examples 'an interface' do 

  let(:record_as_ot) { Octothorpe.new(record) }


  describe '#id_fld' do
    it 'is an attribute that stores a symbol' do
      expect( interface.id_fld ).not_to be_nil
      expect( interface.id_fld ).to be_a_kind_of(Symbol)
    end
  end
  ##


  describe '#list' do

    # individual tests must cover the format of the parameter and whether it
    # performs selection correctly.

    it 'will allow itself to be called with no parameter' do
      expect{ interface.list }.not_to raise_exception
    end

    it 'returns an array of Octothorpes' do
      expect( interface.list       ).to be_a_kind_of Array
      expect( interface.list.first ).to be_a_kind_of Octothorpe
    end

    it 'has the ID field as one of the Octothorpe keys' do
      expect( interface.list.first.to_h ).to have_key interface.id_fld
    end

    it 'returns an empty array if there is no data' do
      # remove all the data
      interface.list.
        each {|x| interface.delete( x[interface.id_fld] ) }

      expect( interface.list ).to eq([])
    end

  end
  ##
  

  describe '#create' do

    # individual tests must cover raising DatabaseError if passed a bad record

    it 'requires a hash or an Octothorpe' do
      expect{ interface.create      }.to raise_exception ArgumentError
      expect{ interface.create(nil) }.to raise_exception ArgumentError
      expect{ interface.create(3)   }.to raise_exception ArgumentError

      expect{ interface.create(record)       }.not_to raise_exception
      expect{ interface.create(record_as_ot) }.not_to raise_exception
    end

    it 'returns the ID' do
      record_id = interface.create(record)
      expect{ interface.read(record_id) }.not_to raise_exception
      expect( interface.read(record_id).to_h ).to include record
    end

    it 'sets the record in the datastore' do
      interface.create(record)
      expect( interface.list.first.to_h ).to include record
    end

  end
  ##


  describe '#read' do

    before do
      interface.create(record)
      @id = interface.list.first[interface.id_fld]
    end


    # individual tests must cover whether the interface updates the record
    # correctly and whether it raises DatabaseError when passed a bad record

    it 'requires an ID' do
      expect{ interface.read      }.to raise_exception ArgumentError
      expect{ interface.read(nil) }.to raise_exception ArgumentError

      expect{ interface.read(@id) }.not_to raise_exception
    end

    it 'returns an Octothorpe' do
      expect( interface.read(@id) ).to be_a_kind_of Octothorpe
    end

  end
  ##


  describe '#update' do

    before do
      interface.create(record)
      @id = interface.list.first[interface.id_fld]
    end

    
    # individual tests must cover raising DatabaseError if something goes
    # wrong, and checking that changes to the record are good.

    it 'requires an ID and a record (hash or OT)' do
      expect{ interface.update      }.to raise_exception ArgumentError
      expect{ interface.update(nil) }.to raise_exception ArgumentError
      expect{ interface.update(14)  }.to raise_exception ArgumentError

      expect{ interface.update(@id, record) }.not_to raise_exception
    end
 
    it 'returns self' do
      expect( interface.update(@id, record) ).to eq interface
    end

  end
  ##


  describe '#delete' do

    def list_contains(id)
      interface.list.find {|x| x[interface.id_fld] == id } 
    end

    before do
      interface.create(record)
      @id = interface.list.first[interface.id_fld]
    end


    it 'requires an id' do
      expect{ interface.delete      }.to raise_exception ArgumentError
      expect{ interface.delete(nil) }.to raise_exception ArgumentError

      expect{ interface.delete(@id) }.not_to raise_exception
    end

    it 'returns self' do
      expect( interface.delete(@id) ).to eq interface
    end

    it 'makes the record at ID go away' do
      expect( list_contains(@id) ).to be_truthy
      interface.delete(@id)
      expect( list_contains(@id) ).to be_falsy
    end

  end
  ##

end
