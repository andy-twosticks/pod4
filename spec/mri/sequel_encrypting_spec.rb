require "pod4"
require "pod4/sequel_interface"
require "pod4/encrypting"
require "sequel"

require_relative '../fixtures/database'


describe "(writing encrypted data via sequel_interface)" do

  def db_setup(connection)
    connection.run(%Q| drop table if exists medical;
                       create table medical ( 
                         id      serial primary key,
                         nonce   text,
                         name    text,
                         ailment text );| )

  end

  def db_truncate(connection)
    connection.run(%Q| truncate table medical restart identity; |)
  end


  before(:all) do
    @connection = Sequel.postgres("pod4_test", DB[:sequel])
    db_setup(@connection)
  end

  before(:each) do
    db_truncate(@connection)
    medical_model_class.set_interface medical_interface_class.new(@connection)
  end


  let(:medical_interface_class) do 
    Class.new Pod4::SequelInterface do
      set_table  :medical
      set_id_fld :id
    end
  end

  let(:medical_model_class) do 
    Class.new Pod4::Model do
      include Pod4::Encrypting

      encrypted_columns :name, :ailment
      set_key           "dflkasdgklajndgnalkghlgasdgasdghaalsdg"
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

