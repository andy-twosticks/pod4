require "pod4"
require "pod4/pg_interface"
require "pod4/encrypting"
require "pg"

require_relative '../fixtures/database'


describe "(writing encrypted data via pg_interface)" do

  def db_setup(connect)
    client = PG.connect(connect)
    client.exec(%Q| drop table if exists medical;
                    create table medical ( 
                      id      serial primary key,
                      nonce   text,
                      name    text,
                      ailment text );| )

  ensure
    client.finish if client
  end

  def db_truncate(connect)
    client = PG.connect(connect)
    client.exec(%Q| truncate table medical restart identity; |)
  ensure
    client.finish if client
  end


  before(:all) do
    @connect_hash = DB[:pg]
    db_setup(@connect_hash)
  end

  before(:each) do
    db_truncate(@connect_hash)
    medical_model_class.set_interface medical_interface_class.new(@connect_hash)
  end


  let(:medical_interface_class) do 
    Class.new Pod4::PgInterface do
      set_table  :medical
      set_id_fld :id
    end
  end

  let(:medical_model_class) do 
    Class.new Pod4::Model do
      include Pod4::Encrypting

      encrypted_columns :name, :ailment
      set_key           "dflkasdgklajnlga"
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

