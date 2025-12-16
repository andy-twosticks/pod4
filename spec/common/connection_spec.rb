require 'pod4/connection'
require 'pod4/null_interface'


##
# I can't make these anonymous classes in an Rspec `let`, because the name of the interface class is
# passed to the Connection object when it is initialised.
##

class ConnectionTestingI < Interface
  def initialize;                         end
  def close_connection;                   end
  def new_connection(args); {conn: args}; end
end

class ConnectionTestingIBad < Interface
  def initialize;           end
  def close_connection;     end
  def new_connection(args); end
end


describe Pod4::Connection do

  let(:interface) { ConnectionTestingI.new }
  let(:conn)      { Pod4::Connection.new(interface: ConnectionTestingI) }


  describe "#new" do

    it "takes an optional hash" do
      expect{ Pod4::Connection.new         }.not_to raise_error
      expect{ Pod4::Connection.new(foo: 4) }.not_to raise_error
      expect{ Pod4::Connection.new(:foo)   }.to raise_error ArgumentError
    end

    it "the :interface parameter must be a Pod4::Interface class" do
      expect{ Pod4::Connection.new(interface: "foo") }.to raise_error ArgumentError
      expect{ Pod4::Connection.new(interface: Array) }.to raise_error ArgumentError
      expect{ Pod4::Connection.new(interface: ConnectionTestingI) }.not_to raise_error
      
      expect( conn.interface_class ).to eq ConnectionTestingI
    end

  end # of #new


  describe "#data_layer_options" do

    it "stores an arbitrary object" do
      expect( conn.data_layer_options ).to be_nil

      conn.data_layer_options = {one: 2, three: 4}

      expect( conn.data_layer_options ).to eq(one: 2, three: 4)
    end

  end # of #data_layer_options


  describe "#close" do

    it "raises ArgumentError if given an interface that wasn't the one you passed in #new" do
      i = ConnectionTestingIBad.new
      expect{ conn.close(i) }.to raise_error ArgumentError
    end

    it "calls close on the interface" do
      expect(interface).to receive(:close_connection)

      conn.close(interface)
    end

    it "resets the stored client" do
      conn.close(interface)

      # Now the stored client should be unset, so a further call to #client should ask the
      # interface for one
      expect(interface).to receive(:new_connection)

      conn.client(interface)
    end

  end # of #close


  describe "#client" do

    it "takes an interface object" do
      expect{ conn.client     }.to raise_exception ArgumentError
      expect{ conn.client(14) }.to raise_exception ArgumentError

      expect{ conn.client(interface) }.not_to raise_exception
    end

    it "raises ArgumentError if given an interface that wasn't the one you passed in #new" do
      i = ConnectionTestingIBad.new
      expect{ conn.client(i) }.to raise_error ArgumentError
    end

    context "when it has no connection" do

      it "calls new_connection on the interface" do
        expect(interface).to receive(:new_connection).with("bar").and_call_original

        conn.data_layer_options = "bar"

        expect( conn.client(interface) ).to eq(conn: "bar")
      end

    end

    context "when it has a connection" do

      it "returns what it has" do
        # set things up like before so we have an existing connection
        conn.data_layer_options = "foo"
        conn.client(interface) 

        expect(interface).not_to receive(:new_connection)

        expect( conn.client(interface) ).to eq(conn: "foo")
      end

    end

  end # of #client


end
