require 'octothorpe'


##
# These are the shared tests for all interfaces. To use them you need to
# supply:
# * record - a record to insert
# * interface - an instance of the interface to call.
#
# For example (from nebulous_interface_spec):
#
#     it_behaves_like 'an interface' do
#       let(:record) { {id: 1, name: 'percy', price: 1.23} }
#
#       let(:interface) do
#         init_nebulous
#         TestNebulousInterface.new( FakeRequester.new )
#       end
#     end
#
# Note that these shared tests only test the common parts of the API that the
# interface exposes to the *model*; they make no assumptions about where your
# test data is coming from, or how you are calling or mocking whatever library
# the interface is an adapter to. 
#
# It's up to the individual specs to test that the interface is calling its
# library correctly and deal with all the things specific to that interface -
# which includes how the model calls new() and list(), for example.
#
RSpec.shared_examples 'an interface' do 

  let(:record_as_ot) { Octothorpe.new(record) }


  describe '#id_fld' do
    it 'is an attribute that stores a symbol' do
      expect( interface.id_fld ).not_to be_nil
      expect( interface.id_fld ).to be_a_kind_of Symbol
    end
  end
  ##


  describe '#create' do

    it 'requires a hash or an Octothorpe' do
      expect{ interface.create      }.to raise_exception ArgumentError
      expect{ interface.create(nil) }.to raise_exception ArgumentError
      expect{ interface.create(3)   }.to raise_exception ArgumentError

      expect{ interface.create(record)       }.not_to raise_exception
      expect{ interface.create(record_as_ot) }.not_to raise_exception
    end

    it 'returns the ID', focus: true do   #bamf
      record_id = interface.create(record)
      expect{ interface.read(record_id) }.not_to raise_exception
      expect( interface.read(record_id).to_h ).to include record
    end

  end
  ##


  describe '#read' do

    before do
      interface.create(record)
      @id = interface.list.first[interface.id_fld]
    end

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

  end
  ##


  describe '#list' do

    it 'will allow itself to be called with no parameter' do
      expect{ interface.list }.not_to raise_exception
    end

    it 'returns an array of Octothorpes' do
      interface.create(record)
      expect( interface.list       ).to be_a_kind_of Array
      expect( interface.list.first ).to be_a_kind_of Octothorpe
    end

    it 'has the ID field as one of the Octothorpe keys' do
      interface.create(record)
      expect( interface.list.first.to_h ).to have_key interface.id_fld
    end

  end
  ##
  

end

