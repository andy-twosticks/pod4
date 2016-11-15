require 'pod4/nebulous_interface'

require 'nebulous_stomp'
require 'nebulous_stomp/nebrequest_null'

require_relative 'shared_examples_for_interface'


##
# In order to conform with 'acts_like an interface', our CRUDL routines must
# pass a single value as the record, which we are making an array. When you
# subclass NebulousInterface for your model, you don't have to follow that; you
# can have a parameter per nebulous parameter, if you want, buy overriding the
# CRUDL methods.
#
class TestNebulousInterface < NebulousInterface
  set_target 'faketarget'
  set_id_fld :id

  set_verb :create, 'custcreate', :name, :price
  set_verb :read,   'custread',   :id
  set_verb :update, 'custupdate', :id, :name, :price
  set_verb :delete, 'custdelete', :id
  set_verb :list,   'custlist',   :name
end
##


##
# This is the class we will pass an instance of to NebulousInterface to use as
# a cut-out for creating Nebulous::NebRequest objects.  
#
# If we pass an instance of this class to NebulousInterface it will call our
# send method instead of creating a NebRequest instance by itself. (It expects
# send to return a Nebrequest instance, or something that behaves like one.)
#
# This means we can cut Nebulous out of the loop and don't need a real
# responder. We can also check the behaviour of NebulousInterface by using
# RSpec 'inspect' syntax on our cutout object.
#
# We're basically emulating both a responder and a data source here (!)
#
class FakeRequester

  def initialize(data={}); @data = data; end


  def send(verb, paramStr, withCache)
    array = (paramStr || '').split(',')

    hash1 = { stompHeaders: nil,
              stompBody:    '',
              verb:         '',
              params:       '',
              desc:         '',
              replyTo:      nil,
              replyId:      nil,
              inReplyTo:    nil,
              contentType:  'application/json' }

    case verb
      when 'custcreate'
        id = create(*array)
        hash2 = {verb: 'success', params: id.to_s}

      when 'custread'
        record = @data[paramStr.to_i]
        hash2  = { stompBody: (record ? record.to_json : ''.to_json) }

      when 'custupdate'
        hash2 = update(*array) ? {verb: 'success'} : {verb: 'error' }

      when 'custdelete'
        hash2 = 
          if @data.delete(paramStr.to_i)
            {verb: 'success'} 
          else
            {verb: 'error'}
          end

      when 'custlist'
        subset = @data.values
        if paramStr && !array[0].empty?
          subset.select!{|x| x[:name] == array[0] }
        end
        hash2 = { stompBody: subset.to_json }

    end

    req = NebulousStomp::NebRequestNull.new('faketarget', verb, paramStr)
    hash2[:inReplyTo] = req.replyID

    mess = NebulousStomp::Message.from_cache( hash1.merge(hash2).to_json )
    req.insert_fake_stomp(mess)
    req
  end


  def create(name, price)
    id = @data.keys.sort.last.to_i + 1
    @data[id] = {id: id, name: name, price: price.to_f}
    id
  end


  def update(id, name, price)
    return nil unless @data[id.to_i]
    @data[id.to_i] = {id: id.to_i, name: name, price: price.to_f}
  end

end
##



describe TestNebulousInterface do

  def init_nebulous
    stomp_hash = { hosts: [{ login:    'guest',
                             passcode: 'guest',
                             host:     '10.0.0.150',
                             port:     61613,
                             ssl:      false }],
                   reliable: false }

    # We turn Redis off for this test; we're not testing Nebulous here.
    NebulousStomp.init( :stompConnectHash => stomp_hash,
                        :redisConnectHash => {},
                        :messageTimeout   => 5,
                        :cacheTimeout     => 20 )

    NebulousStomp.add_target( :faketarget,
                              :sendQueue      => "/queue/fake.in",
                              :receiveQueue   => "/queue/fake.out",
                              :messageTimeout => 1 )

  end


  it_behaves_like 'an interface' do
    let(:record) { {id: 1, name: 'percy', price: 1.23} }

    let(:interface) do 
      init_nebulous
      TestNebulousInterface.new( FakeRequester.new )
    end

  end
  ##


  let(:data) do
    { 1 => {id: 1, name: 'Barney', price: 1.11},
      2 => {id: 2, name: 'Fred',   price: 2.22},
      3 => {id: 3, name: 'Betty',  price: 3.33} }
  end

  let(:interface) do
    init_nebulous
    TestNebulousInterface.new( FakeRequester.new(data) )
  end


  describe '#new' do

    it 'requires no parameters' do
      expect{ TestNebulousInterface.new }.not_to raise_exception
    end

  end
  ##


  describe '#create' do

    let(:hash) { {name: 'Bam-Bam', price: 4.44} }
    let(:ot)   { Octothorpe.new(name: 'Wilma', price: 5.55) }

    it 'creates the record when given a hash' do
      id = interface.create(hash)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include hash
    end

    it 'creates the record when given an Octothorpe' do
      id = interface.create(ot)

      expect{ interface.read(id) }.not_to raise_exception
      expect( interface.read(id).to_h ).to include ot.to_h
    end

  end
  ##


  describe '#read' do

    it 'returns the record for the id as an Octothorpe' do
      expect( interface.read(1)      ).to be_a_kind_of Octothorpe
      expect( interface.read(2).to_h ).
        to include(name: 'Fred', price: 2.22)

    end

    it 'returns an empty Octothorpe if no record matches the ID' do
      expect{ interface.read(99) }.not_to raise_exception
      expect( interface.read(99) ).to be_a_kind_of Octothorpe
      expect( interface.read(99) ).to be_empty
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
      expect( arr ).to match_array data.values
    end

    it 'returns a subset of records based on the selection parameter' do
      expect( interface.list(name: 'Fred').size ).to eq 1

      expect( interface.list(name: 'Betty').first.to_h ).
        to include(name: 'Betty', price: 3.33)

    end

    it 'returns an empty Array if nothing matches' do
      expect( interface.list(name: 'Yogi') ).to eq([])
    end

    it 'returns an empty array if there is no data' do
      interface.list.each{|x| interface.delete(x[interface.id_fld]) }
      expect( interface.list ).to eq([])
    end

  end
  ##
  

  describe '#update' do

    let(:id) { interface.list.first[:id] }

    it 'updates the record at ID with record parameter' do
      rec = {price: 99.99}
      interface.update(id, rec)

      expect( interface.read(id).to_h ).to include(rec)
    end

  end
  ##


  describe '#delete' do

    let(:id) { interface.list.first[:id] }

    def list_contains(id)
      interface.list.find {|x| x[interface.id_fld] == id }
    end

    it 'raises CantContinue if anything hinky happens with the ID' do
      expect{ interface.delete(:foo) }.to raise_exception CantContinue
      expect{ interface.delete(99)   }.to raise_exception CantContinue
    end

    it 'makes the record at ID go away' do
      expect( list_contains(id) ).to be_truthy
      interface.delete(id)
      expect( list_contains(id) ).to be_falsy
    end

  end
  ##


end
