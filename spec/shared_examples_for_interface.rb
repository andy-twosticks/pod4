require 'octothorpe'


# **ANDY** -- the assumptions below are dumb ones. The shared examples should
# test the API that the interface presents to the model, and only that, It
# can't test that the interface is calling the underlying data source library
# correctly, becaue it's different in each case. And it **can't** do what it
# does now, and assume that we can magically fake the whole data source
# library, because that's not practical for, say, raw SQL -- and if the
# interface spec wants to use a real database, that's up to that spec, and
# shouldn't be a constraint!
#
# We will, I think, have to resort to using a real database for the TDS and PG
# interface tests. But, that shouldn't be something that effects the shared
# examples.
#
# Proposal: this shared file should expect interface and record, with the
# understanding that if you use them together, the interface will not return an
# error. That's it.  It will allow these shared examples to test basic return
# values, like read() returning an OT. I've marked anything beyond that in the
# code. (Do we need record_id?)
# -------
#
#
# We make the assumption here that you have somehow managed to simulate a
# working data source -- that is, delete actually deletes, create actually
# creates, etc.  Sorry about that. For SequelModel we use an in-memory SQLite
# dataabase; for NebulousModel we have a little class which we can insert
# instances of and then track.  This fake data source should start off with no
# data in it.
#
# To comply with this shared test file, you also need to supply:
# * record - a record to insert
# * record_id - the id of the record to insert
# * interface - an instance of the interface to call.
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

    it 'sets the record in the datastore' do   # bamf -- to go?
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

    it 'makes the record at ID go away' do   # bamf - to go?
      expect( list_contains(@id) ).to be_truthy
      interface.delete(@id)
      expect( list_contains(@id) ).to be_falsy
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
      interface.create(record)
      expect( interface.list       ).to be_a_kind_of Array
      expect( interface.list.first ).to be_a_kind_of Octothorpe
    end

    it 'has the ID field as one of the Octothorpe keys' do
      interface.create(record)
      expect( interface.list.first.to_h ).to have_key interface.id_fld
    end

    it 'returns an empty array if there is no data' do   # bamf - to go?
      interface.list.each{|x| interface.delete(x[interface.id_fld]) }
      expect( interface.list ).to eq([])
    end

  end
  ##
  

end

