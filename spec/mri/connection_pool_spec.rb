require "pod4/pg_interface"
require "pg"

require_relative "../fixtures/database"


describe "PgInterface" do

  def db_setup(connect)
    client = PG.connect(connect)

    client.exec(%Q|
      drop table if exists flobert;

      create table flobert (
        id   serial primary key,
        code text,
        name text );

      insert into flobert (code, name) 
        values ( 'one', 'first code');| )

  ensure
    client.finish if client
  end

  # we can't use Pod4 to get the connections because it will reuse the current connection!
  def get_connections(connect)
    client = PG.connect(connect)
    result = client.exec %Q|select * from pg_stat_activity   
                              where datname = 'pod4_test'
                                and query like '%flobert%'
                                and not (query like '%pg_stat_activity%');|

    rows = result.map{it}
    client.finish
    rows
  end

  let(:pg_interface_class) do
    Class.new PgInterface do
      set_table :flobert
      set_id_fld :id
    end
  end

  let(:interface) do
    pg_interface_class.new(@pool)
  end

  before(:all) do
    @connect_hash = DB[:pg]
    db_setup(@connect_hash)

    @pool = ConnectionPool.new(interface: PgInterface)
    @pool.data_layer_options = @connect_hash
  end


  describe "#close" do
    # we're specifically and only testing here that the connection goes away after manually calling
    # close.  In the common unit tests we test that #client calls #close_connection on the
    # interface when it needs to release a connection.

    it "drops the database connection" do
      list = interface.list

      rows = get_connections(@connect_hash)
      expect( rows.count ).to eq 1

      @pool.close interface

      rows = get_connections(@connect_hash)
      expect( rows.count ).to eq 0
    end

  end # of #close


end

