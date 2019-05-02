require "date"
require "openssl"
require "base64"
require "octothorpe"

require "pod4"
require "pod4/encrypting"
require "pod4/null_interface"
require "pod4/errors"


describe "(Model with Encryption)" do

  ##
  # Encrypt / decrypt
  #
  def encrypt(key, iv=nil, plaintext)
    cipher = OpenSSL::Cipher.new(iv ? Pod4::Encrypting::CIPHER_IV : Pod4::Encrypting::CIPHER_NO_IV)
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv if iv

    answer = (plaintext.empty? ? "" : cipher.update(plaintext) ) + cipher.final
    Base64.strict_encode64(answer)
  end

  let(:encryption_key) { "dflkasdgklajndgn" }

  let(:medical_model_class) do  # model with an IV column
    Class.new Pod4::Model do
      include Pod4::Encrypting
      attr_columns :id, :nhs_no  # note, we don't bother to name encrypted columns
      encrypted_columns :name, :ailment, :prescription
      set_key "dflkasdgklajndgn"
      set_iv_column :nonce

      ifce = NullInterface.new(:id, :nhs_no, :name, :ailment, :prescription, :nonce, [])
      ifce.id_ai = false
      set_interface ifce
    end
  end

  let(:medical_model_bad_class) do  # model with an IV column and a very very short key
    Class.new Pod4::Model do
      include Pod4::Encrypting
      attr_columns :id, :nhs_no  # note, we don't bother to name encrypted columns
      encrypted_columns :name, :ailment, :prescription
      set_key "d"
      set_iv_column :nonce

      ifce = NullInterface.new(:id, :nhs_no, :name, :ailment, :prescription, :nonce, [])
      ifce.id_ai = false
      set_interface ifce
    end
  end

  let(:medical_model_nokey_class) do  # model with no encryption key
    Class.new Pod4::Model do
      include Pod4::Encrypting
      attr_columns :id, :nhs_no 
      encrypted_columns :name, :ailment, :prescription
      set_key nil
      set_iv_column :nonce

      ifce =  NullInterface.new(:id, :nhs_no, :name, :ailment, :prescription, :nonce, [])
      ifce.id_ai = false
      set_interface ifce
    end
  end

  let(:diary_model_class) do  # model without an IV column
    Class.new Pod4::Model do
      include Pod4::Encrypting
      attr_columns :id, :date, :heading, :text
      encrypted_columns :heading, :text
      set_key "dflkasdgklajndgn"

      ifce = NullInterface.new(:id, :date, :heading, :text, [])
      ifce.id_ai = false
      set_interface ifce
    end
  end

  let(:m40) do
    m = medical_model_class.new
    m.id           = 40
    m.nhs_no       = "123456"
    m.name         = "fred"
    m.ailment      = "sore toe"
    m.prescription = "suck thumb"
    m
  end

  let(:d44) do
    d = diary_model_class.new
    d.id      = 44
    d.date    = Date.new(2018,4,14)
    d.heading = "fred"
    d.text    = "sore toe"
    d
  end

  let(:m40_record) { m40.interface.read(40) }
  let(:d44_record) { d44.interface.read(44) }


  describe "Model::CIPHER_IV" do

    it "should be a valid string to initialize OpenSSL::Cipher" do
      expect{ OpenSSL::Cipher.new(medical_model_class::CIPHER_IV) }.not_to raise_exception
    end

  end # of Model::CIPHER_IV


  describe "Model::CIPHER_NO_IV" do

    it "should be a valid string to initialize OpenSSL::Cipher" do
      expect{ OpenSSL::Cipher.new(medical_model_class::CIPHER_NO_IV) }.not_to raise_exception
    end

  end # of Model::CIPHER_NO_IV


  describe "Model.set_key" do

    it "requires a string" do
      expect( medical_model_class ).to respond_to(:set_key).with(1).argument
    end

  end # of Model.set_key


  describe "Model.encryption_key" do

    it "returns the key passed to set_key" do
      expect( medical_model_class.encryption_key ).to eq encryption_key
    end
    
  end # of Model.encryption_key


  describe "Model.set_iv_column" do

    it "requires an IV column" do
      expect( medical_model_class ).to respond_to(:set_iv_column).with(1).argument
    end

    it "exposes the encryption_iv attribute, just like attr_accessor" do
      m20 = medical_model_class.new(20)
      expect( m20 ).to respond_to(:nonce)
      expect( m20 ).to respond_to(:nonce=)
    end

    # See also: Model#encryption_iv

  end # of Model.set_iv_column


  describe "Model.encryption_iv_column" do

    it "returns the column passed to set_iv_column" do
      expect( medical_model_class.encryption_iv_column ).to eq :nonce
    end
    
  end # of Model.encryption_iv_column
  

  describe "Model.encrypted_columns" do

    it "requires a list of columns" do
      expect( medical_model_class ).to respond_to(:encrypted_columns).with(1).argument
    end

    it "adds the columns to the model's column list, just like attr_columns" do
      expect( medical_model_class.columns ).
        to match_array( %i|id nonce nhs_no name ailment prescription| )

      expect( diary_model_class.columns ).to match_array( %i|id date heading text| )
    end

    it "exposes the columns just like attr_accessor" do
      m20 = medical_model_class.new(20)

      expect( m20 ).to respond_to(:name)
      expect( m20 ).to respond_to(:ailment)
      expect( m20 ).to respond_to(:prescription)
      expect( m20 ).to respond_to(:name=)
      expect( m20 ).to respond_to(:ailment=)
      expect( m20 ).to respond_to(:prescription=)
    end
    
  end # of Model.encrypted_columns


  describe "Model.encryption_columns" do

    it "exposes the columns given in encrypted_columns" do
      expect( medical_model_class.encryption_columns ).
        to match_array( %i|name ailment prescription| )

    end
    
  end # of Model.encryption_columns
  

  describe "(Creating a record)" do

    context "when we don't have a key" do

      it "writes the record without freaking out" do
        m = medical_model_nokey_class.new
        m.id           = 666
        m.nhs_no       = "666666"
        m.name         = "joe"
        m.ailment      = "brain cloud"
        m.prescription = "volcano"

        expect{ m.create }.not_to raise_exception

        record = m.interface.read(666)
        expect( record.>>.nhs_no       ).to eq "666666"
        expect( record.>>.name         ).to eq "joe"
        expect( record.>>.ailment      ).to eq "brain cloud"
        expect( record.>>.prescription ).to eq "volcano"
      end

    end
    
    context "when we don't have an IV column" do

      it "scrambles the encrypted columns and leaves the others alone" do
        d44.create
        expect( d44_record.>>.date    ).to eq d44.date
        expect( d44_record.>>.heading ).not_to eq d44.heading
        expect( d44_record.>>.text    ).not_to eq d44.text
      end

    end
    
    context "when we have an IV column" do
       
      it "writes an IV to the nonce field" do
        m40.create
        expect( m40_record.>>.nonce ).not_to be_nil

        recordiv = Base64.strict_decode64(m40_record.>>.nonce)
        expect( recordiv ).to eq m40.nonce
        expect( recordiv ).to eq m40.encryption_iv
      end

      it "scrambles the encrypted columns and leaves the others alone" do
        m40.create
        expect( m40_record.>>.nhs_no       ).to eq m40.nhs_no
        expect( m40_record.>>.name         ).not_to eq m40.name
        expect( m40_record.>>.ailment      ).not_to eq m40.ailment
        expect( m40_record.>>.prescription ).not_to eq m40.prescription
      end

    end

  end # of (Creating a record)


  describe "(reading a record)" do

    context "when we don't have a key" do
       
      it "reads the record without freaking out" do
        m = medical_model_nokey_class.new
        m.id           = 666
        m.nhs_no       = "666666"
        m.name         = "joe"
        m.ailment      = "brain cloud"
        m.prescription = "volcano"
        expect{ m.create }.not_to raise_exception

        m666 = medical_model_nokey_class.new(666)
        expect{ m666.read }.not_to raise_exception
        expect( m666.model_status ).not_to eq :error
        expect( m666.nhs_no       ).to eq "666666"
        expect( m666.name         ).to eq "joe"
        expect( m666.ailment      ).to eq "brain cloud"
        expect( m666.prescription ).to eq "volcano"
      end

    end

    context "when we have no IV column" do
      before(:each) { d44.create }

      it "decrypts the columns" do
        d = diary_model_class.new(44).read
        expect( d.date    ).to eq Date.new(2018,4,14)
        expect( d.heading ).to eq "fred"
        expect( d.text    ).to eq "sore toe"
      end

    end
    
    context "when we have an IV column" do
      before(:each) { m40.create }

      it "returns the IV field as encryption_iv" do
        m = medical_model_class.new(40).read
        expect( m.encryption_iv ).not_to be_nil
        expect( m.encryption_iv ).to eq m.nonce
      end

      it "decrypts the columns" do
        m = medical_model_class.new(40).read
        expect( m.nhs_no       ).to eq "123456"
        expect( m.name         ).to eq "fred"
        expect( m.ailment      ).to eq "sore toe"
        expect( m.prescription ).to eq "suck thumb"
      end

      it "handles the case of a record with no IV (not encrypted)" do
        ot = Octothorpe.new( id:           80,
                             nhs_no:       "abc",
                             name:         "sally",
                             ailment:      "short-sighted",
                             prescription: "glasses",
                             nonce:        nil )

        m80 = medical_model_class.new(80)
        allow( m80.interface ).to receive(:read).with(80).and_return(ot)

        m80.read
        expect( m80.nhs_no       ).to eq "abc"
        expect( m80.name         ).to eq "sally"
        expect( m80.ailment      ).to eq "short-sighted"
        expect( m80.prescription ).to eq "glasses"
      end

    end

  end # of (reading a record)
  

  describe "Model#(encryption_iv field)" do

    it "returns nil for a new model object" do
      m = medical_model_class.new
      m.id = 50
      expect( m.nonce ).to be_nil
    end

    it "returns the nonce for an existing record" do
      expect( m40.nonce ).to eq m40_record.>>.nonce
    end

  end # of Model#(encryption_iv field)


  describe "Model#encryption_iv" do

    it "returns nil for a new model object" do
      m = medical_model_class.new
      m.id = 50

      expect( m.encryption_iv ).to be_nil
    end

    it "returns nil if we don't have an IV set" do
      d44.create
      expect( d44.encryption_iv ).to be_nil
    end

    it "returns the nonce for an existing record" do
      expect( m40.encryption_iv ).to eq m40_record.>>.nonce
    end

    it "returns the same as the actual IV field" do
      expect( m40.encryption_iv ).to eq m40.nonce
    end

  end # of Model#encryption_iv


  describe "Model#encrypt & Model#decrypt" do

    it "encrypts and decrypts when the model has no IV" do
      d = diary_model_class.new
      expect( d.decrypt(d.encrypt "foobar123") ).to eq "foobar123"
    end

    it "encrypts and decrypts when the model has IV" do
      m = medical_model_class.new
      expect( m.decrypt(m.encrypt "plonkplink987") ).to eq "plonkplink987"
    end

  end # of Model#encrypt & Model#decrypt


  describe "Model#map_to_interface" do

    it "raises Pod4Error if there is an encryption problem, eg, key too short" do
      bad = medical_model_bad_class.new
      bad.id           = 999
      bad.nhs_no       = "12345"
      bad.name         = "alice"
      bad.ailment      = "tiny key"
      bad.prescription = "raise an exception"

      expect{ bad.map_to_interface }.to raise_exception Pod4::Pod4Error
    end

    it "doesn't freak out when asked to encrypt an empty column" do
      bad = medical_model_class.new
      bad.id      = 998
      bad.nhs_no  = "12345"
      bad.name    = ""
      bad.ailment = nil

      expect{ bad.map_to_interface }.not_to raise_exception
    end

    context "when we don't have an IV column" do

      it "encrypts only the encryptable columns for the interface" do
        ot = d44.map_to_interface
        expect( ot.>>.date    ).to eq Date.new(2018,4,14)
        expect( ot.>>.heading ).to eq encrypt(encryption_key, "fred")
        expect( ot.>>.text    ).to eq encrypt(encryption_key, "sore toe")
      end

    end

    context "when we have an IV column" do
      before(:each) { m40.create }

      it "sets the IV column on create" do
        expect( m40_record.>>.nonce ).not_to be_nil
      end

      it "encrypts only the encryptable columns for the interface" do
        ot = m40.map_to_interface
        iv = m40.nonce
        expect( ot.>>.nhs_no       ).to eq "123456"
        expect( ot.>>.name         ).to eq encrypt(encryption_key, iv, "fred")
        expect( ot.>>.ailment      ).to eq encrypt(encryption_key, iv, "sore toe")
        expect( ot.>>.prescription ).to eq encrypt(encryption_key, iv, "suck thumb")
      end

    end
    
  end # of Model#map_to_interface


  describe "Model#map_to_model" do

    context "when we don't have an IV column" do

      it "decrypts only the encryptable columns for the model" do
        d44.create

        d = diary_model_class.new(44)
        expect( d44_record.>>.heading ).not_to eq "fred"
        expect( d44_record.>>.text    ).not_to eq "sore toe"

        d.read
        expect( d.date    ).to eq Date.new(2018,4,14)
        expect( d.heading ).to eq "fred"
        expect( d.text    ).to eq "sore toe"
      end

      it "successfully decrypts an empty column" do
        d44.text = ""
        d44.create

        d = diary_model_class.new(44)
        d.read
        expect( d.text ).to eq ""
      end

    end 

    context "when we have an IV column" do

      it "decrypts only the encryptable columns for the model" do
        m40.create

        m = medical_model_class.new(40)
        expect( m40_record.>>.name         ).not_to eq "fred"
        expect( m40_record.>>.ailment      ).not_to eq "sore toe"
        expect( m40_record.>>.prescription ).not_to eq "suck thumb"

        m.read
        expect( m.nhs_no       ).to eq "123456"
        expect( m.name         ).to eq "fred"
        expect( m.ailment      ).to eq "sore toe"
        expect( m.prescription ).to eq "suck thumb"
      end
       
      it "successfully decrypts an empty column" do
        m40.ailment      = ""
        m40.prescription = nil
        m40.create

        m = medical_model_class.new(40)
        m.read
        expect( m.ailment      ).to eq ""
        expect( m.prescription ).to be_nil
      end


    end
    
  end # of Model#map_to_model
       

end

