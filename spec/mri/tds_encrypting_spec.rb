require "pod4"
require "pod4/tds_interface"
require "pod4/encrypting"
require "tiny_tds"

require_relative '../fixtures/database'


describe "(writing encrypted data via tds_interface)" do

  def db_setup(connect)
    client = TinyTds::Client.new(connect)
    client.execute(%Q|use [pod4_test];|).do

    # Our SQL Server does not support DROP TABLE IF EXISTS !
    # This is apparently an SQL-agnostic way of doing it:
    client.execute(%Q|
      if exists (select * from INFORMATION_SCHEMA.TABLES 
                     where TABLE_NAME   = 'medical' 
                       and TABLE_SCHEMA = 'dbo' )
            drop table dbo.medical;

      create table dbo.medical ( 
        id        int identity(1,1) not null,
        nonce     nvarchar(max),
        name      nvarchar(max),
        ailment   nvarchar(max) );| ).do

  ensure
    client.close if client
  end

  def db_truncate(connect)
    client = TinyTds::Client.new(connect)
    client.execute(%Q|use [pod4_test];|).do
    client.execute(%Q| truncate table medical; |).do
  ensure
    client.close if client
  end


  before(:all) do
    @connect_hash = DB[:tds]
    db_setup(@connect_hash)
  end

  before(:each) do
    db_truncate(@connect_hash)
    medical_model_class.set_interface medical_interface_class.new(@connect_hash)
  end


  let(:medical_interface_class) do 
    Class.new Pod4::TdsInterface do
      set_db     :pod4_test
      set_table  :medical
      set_id_fld :id
    end
  end

  let(:medical_model_class) do 
    Class.new Pod4::Model do
      include Pod4::Encrypting

      encrypted_columns :name, :ailment
      set_key           "dflkasdgklajndgn"
      set_iv_column     :nonce
    end
  end

  #####


  it "writes encrypted data to the database" do
    m = medical_model_class.new
    m.name    = "frank"
    m.ailment = "sore toe"

    expect{ m.create }.not_to raise_exception

    record = m.class.interface.list.first
    expect( record ).not_to be_nil
  end

  it "reads encrypted data back from the database" do
    m1 = medical_model_class.new
    m1.name    = "roger"
    m1.ailment = "hiccups"
    m1.create

    m2 = medical_model_class.list.first
    expect( m2 ).not_to be_nil
    expect( m2.name    ).to eq "roger"
    expect( m2.ailment ).to eq "hiccups"
  end

end

