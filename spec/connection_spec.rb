require 'pod4/connection'
require 'pod4/null_interface'


class ConnectionTestingI < Interface
  def initialize;           end
  def close_connection;     end
  def new_connection(args); end
end




describe Connection do

  let(:interface) {ConnectionTestingI.new}

  let(:conn) { Connection.new(:bar) }


  describe "#new" do

    it "will take any number of other arguments as the connection thing" do
      expect{ Connection.new(:one)       }.not_to raise_exception
      expect{ Connection.new(:one, :two) }.not_to raise_exception
      expect{ Connection.new(1, 2, 3)    }.not_to raise_exception

      expect( Connection.new("one"  ).init_thing ).to eq "one"
      expect( Connection.new(1, 2, 3).init_thing ).to eq([1,2,3])
    end

  end
  ##


  describe "#set_connection" do

    it "takes an interface class" do
      expect{ conn.set_connection     }.to raise_exception ArgumentError
      expect{ conn.set_connection(14) }.to raise_exception ArgumentError

      expect{ conn.set_connection(interface, :bar) }.not_to raise_exception
    end

    it "sets the connection object" do
      conn.set_connection(interface, :foo)
      expect( conn.connection(interface) ).to eq :foo
    end

  end
  ##


  describe "#close" do

    it "calls close on the interface" do
      expect(interface).to receive(:close_connection)

      conn.set_connection(interface, :foo)
      conn.close
    end

  end
  ##


  describe "#connection" do
    it "takes an interface class" do
      expect{ conn.connection     }.to raise_exception ArgumentError
      expect{ conn.connection(14) }.to raise_exception ArgumentError

      expect{ conn.connection(interface) }.not_to raise_exception
    end

    context "when it has no connection" do

      it "calls new_connection on the interface" do
        expect(interface).to receive(:new_connection).with(:bar)
        conn.connection(interface)
      end

    end

    context "when it has a connection" do

      it "returns what it has" do
        allow(interface).
          to receive(:new_connection).
          and_return(19,99)

        conn.connection(interface)
        expect( conn.connection(interface) ).to eq 19
      end

    end

  end
  ##


end
