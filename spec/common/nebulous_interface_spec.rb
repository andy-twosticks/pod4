require 'pod4/nebulous_interface'

require 'nebulous_stomp'
require 'nebulous_stomp/stomp_handler_null'

require_relative 'shared_examples_for_interface'


##
# This is the class we will pass an instance of to NebulousInterface to use as a cut-out for
# creating Nebulous::NebRequest objects.  
#
# If we pass an instance of this class to NebulousInterface it will call our send method instead of
# creating a Request instance by itself. (It expects send to return a Request instance, or
# something that behaves like one.)
#
# This means we can cut Nebulous out of the loop and don't need a real responder. We can also check
# the behaviour of NebulousInterface by using RSpec 'inspect' syntax on our cutout object.
#
# We're basically emulating both a responder and a data source here (!)
#
class FakeRequester

  # Helper to record the first message sent to us.
  class << self
    def clear_method;   @@method = nil;  end
    def set_method(x);  @@method ||= x;  end 
    def method;         @@method;        end
  end

  def initialize(data={}); @data = data; end

  ##
  # NebulousInterface will call this to return a NebulousStomp::Request object, or something that
  # behaves like one.
  #
  def send(target, requestmsg)
    hash = response_message_hash(requestmsg)

    stomphandler = NebulousStomp::StompHandlerNull.new

    request = NebulousStomp::Request.new(target, requestmsg)
    request.stomp_handler = stomphandler

    # We need to know which send method was called. Note that #send calls #send_no_cache, so we
    # record the first method called.
    class << request
      def send(*args);          FakeRequester.set_method :send;          super; end
      def send_no_cache(*args); FakeRequester.set_method :send_no_cache; super; end
    end

    hash[:inReplyTo] = request.message.reply_id
    responsemsg  = NebulousStomp::Message.new hash
    stomphandler.insert_fake(responsemsg)

    request
  end

  private

  def create(name, price)
    id = @data.keys.sort.last.to_i + 1
    @data[id] = {id: id, name: name, price: price.to_f}
    id
  end

  def update(id, name, price)
    return nil unless @data[id.to_i]
    @data[id.to_i] = {id: id.to_i, name: name, price: price.to_f}
  end

  def response_message_hash(requestmsg)
    hash1 = { contentType: 'application/json' }

    if requestmsg.params.is_a?(Array)
      array    = requestmsg.params
      paramstr = array.join(',')
    else
      paramstr = requestmsg.params.to_s
      array    = paramstr.split(',')
    end

    case requestmsg.verb
      when 'custcreate'
        id = create(*array)
        hash2 = {verb: 'success', params: id.to_s}

      when 'custread'
        record = @data[paramstr.to_i]
        hash2  = { stompBody: (record ? record.to_json : ''.to_json) }

      when 'custupdate'
        hash2 = update(*array) ? {verb: 'success'} : {verb: 'error' }

      when 'custdelete'
        hash2 = @data.delete(paramstr.to_i) ? {verb: 'success'} : {verb: 'error'}

      when 'custlist'
        subset = @data.values
        subset.select!{|x| x[:name] == array[0] } if (!paramstr.empty? && !array[0].empty?)
        hash2 = { stompBody: subset.to_json }

      when 'custbad'
        hash2 = { verb: 'error', description: 'error verb description' }

    end

    hash1.merge(hash2)
  end

end
##



describe "NebulousInterface" do

  ##
  # In order to conform with 'acts_like an interface', our CRUDL routines must
  # pass a single value as the record, which we are making an array. When you
  # subclass NebulousInterface for your model, you don't have to follow that; you
  # can have a parameter per nebulous parameter, if you want, by overriding the
  # CRUDL methods.
  #
  let(:nebulous_interface_class) do
    Class.new NebulousInterface do
      set_target 'faketarget'
      set_id_fld :id

      set_verb :create, 'custcreate', :name, :price
      set_verb :read,   'custread',   :id
      set_verb :update, 'custupdate', :id, :name, :price
      set_verb :delete, 'custdelete', :id
      set_verb :list,   'custlist',   :name
    end
  end


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
      nebulous_interface_class.new( FakeRequester.new )
    end

  end
  ##


  let(:data) do
    { 1 => {id: 1, name: 'Barney', price: 1.11},
      2 => {id: 2, name: 'Fred',   price: 2.22},
      3 => {id: 3, name: 'Betty',  price: 3.33} }
  end

  let(:fake) { FakeRequester.new(data) }

  let(:interface) do
    init_nebulous
    nebulous_interface_class.new(fake)
  end


  describe '#new' do

    it 'requires no parameters' do
      expect{ nebulous_interface_class.new }.not_to raise_exception
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

    it 'creates a non-caching request' do 
      FakeRequester.clear_method
      id = interface.create(ot)
      expect( FakeRequester.method ).to eq :send_no_cache
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

    it 'creates a caching request' do 
      FakeRequester.clear_method
      id = interface.read(1)
      expect( FakeRequester.method ).to eq :send
    end

    it "creates a non-caching request when passed an option" do
      FakeRequester.clear_method
      id = interface.read(1, caching: false)
      expect( FakeRequester.method ).to eq :send_no_cache
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

    it 'creates a caching request' do 
      FakeRequester.clear_method
      interface.list(name: 'Fred')
      expect( FakeRequester.method ).to eq :send
    end

    it "creates a non-caching request when passed an option" do
      FakeRequester.clear_method
      interface.list({name: 'Fred'}, caching: false)
      expect( FakeRequester.method ).to eq :send_no_cache
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

    it 'creates a non-caching request' do 
      i   = id # creates a request, so get it done now
      rec = {price: 99.99}

      FakeRequester.clear_method
      interface.update(i, rec)
      expect( FakeRequester.method ).to eq :send_no_cache
    end

  end
  ##


  describe '#delete' do

    let(:id) { interface.list.first[:id] }

    def list_contains(id)
      interface.list.find {|x| x[interface.id_fld] == id }
    end

    it 'raises WeakError if anything hinky happens with the ID' do
      expect{ interface.delete(:foo) }.to raise_exception WeakError
      expect{ interface.delete(99)   }.to raise_exception WeakError
    end

    it 'makes the record at ID go away' do
      expect( list_contains(id) ).to be_truthy
      interface.delete(id)
      expect( list_contains(id) ).to be_falsy
    end

    it 'creates a non-caching request' do 
      i   = id # creates a request, so get it done now

      FakeRequester.clear_method
      interface.delete(i)
      expect( FakeRequester.method ).to eq :send_no_cache
    end

  end
  ##


  describe "#send_message" do

    context "when nebulous returns an error verb" do

      it "raises a Pod4::WeakError" do
        expect{ interface.send_message("custbad", nil) }.to raise_exception Pod4::WeakError
      end

    end

  end

end
