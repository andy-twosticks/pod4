require 'pod4/connection'
require 'pod4/null_interface'


class ConnectionTestingI < Interface
  def initialize;           end
  def close_connection;     end
  def new_connection(args); end
end




describe Connection do

  let(:interface) {ConnectionTestingI.new}

  let(:conn) { Connection.new(interface, :bar) }


  describe "#new" do

    it "takes an interface class" do
      expect{ Connection.new     }.to raise_exception ArgumentError
      expect{ Connection.new(14) }.to raise_exception ArgumentError

      expect{ Connection.new(interface) }.not_to raise_exception
    end

    it "will take any number of other arguments as the connection thing" do
      expect{ Connection.new(interface, :one)       }.not_to raise_exception
      expect{ Connection.new(interface, :one, :two) }.not_to raise_exception
      expect{ Connection.new(interface, 1, 2, 3)    }.not_to raise_exception

      expect( Connection.new(interface, "one"  ).init_thing ).to eq "one"
      expect( Connection.new(interface, 1, 2, 3).init_thing ).to eq([1,2,3])
    end

  end
  ##


  describe "#set_connection" do

    it "sets the connection object" do
      conn = Connection.new(interface)
      conn.set_connection(:foo)
      expect( conn.connection ).to eq :foo
    end

  end
  ##


  describe "#close" do

    it "calls close on the interface" do
      expect(interface).to receive(:close_connection)
      conn.close
    end

  end
  ##


  describe "#connection" do

    context "when it has no connection" do

      it "calls new_connection on the interface" do
        expect(interface).to receive(:new_connection).with(:bar)
        conn.connection
      end

    end

    context "when it has a connection" do

      it "returns what it has" do
        allow(interface).
          to receive(:new_connection).
          and_return(19,99)

        conn.connection
        expect( conn.connection ).to eq 19
      end

    end

  end
  ##


end
