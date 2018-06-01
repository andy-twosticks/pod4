require "date"
require "openssl"
require "octothorpe"

require "pod4"
require "pod4/encrypting"
require "pod4/null_interface"


describe "(Model with Encryption)" do

  ##
  # Encrypt / decrypt
  #
  def encrypt(key, iv=nil, plaintext)
    cipher = OpenSSL::Cipher.new(iv ? Pod4::Encrypting::CIPHER_IV : Pod4::Encrypting::CIPHER_NO_IV)
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv if iv
    cipher.update(plaintext) + cipher.final
  end

  let(:encryption_key) { "dflkasdgklajndgnalkghlgasdgasdghaalsdg" }

  let(:medical_model_class) do  # model with an IV column
    Class.new Pod4::Model do
      include Pod4::Encrypting
      attr_columns :id, :nhs_no  # note, we don't bother to name encrypted columns
      encrypted_columns :name, :ailment, :prescription
      set_key "dflkasdgklajndgnalkghlgasdgasdghaalsdg"
      set_iv_column :nonce
      set_interface NullInterface.new(:id, :nhs_no, :name, :ailment, :prescription, :nonce, [])
    end
  end

  let(:diary_model_class) do  # model without an IV column
    Class.new Pod4::Model do
      include Pod4::Encrypting
      attr_columns :id, :date, :heading, :text
      encrypted_columns :heading, :text
      set_key "dflkasdgklajndgnalkghlgasdgasdghaalsdg"
      set_interface NullInterface.new(:id, :date, :heading, :text, [])
    end
  end


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

    context "when we have an IV column" do
      let(:m40) do
        m = medical_model_class.new
        m.id           = 40
        m.nhs_no       = "123456"
        m.name         = "fred"
        m.ailment      = "sore toe"
        m.prescription = "suck thumb"
        m
      end

      let(:m40_record) do
        m40.interface.read(40)
      end
       
      it "writes an IV to the nonce field" do
        m40.create
        expect( m40_record.>>.nonce ).not_to be_nil
        expect( m40_record.>>.nonce ).to eq m40.nonce
        expect( m40_record.>>.nonce ).to eq m40.encryption_iv
      end

      it "scrambles the encrypted columns and leaves the others alone" do
        m40.create
        expect( m40_record.>>.nhs_no       ).to eq m40.nhs_no
        expect( m40_record.>>.name         ).not_to eq m40.name
        expect( m40_record.>>.ailment      ).not_to eq m40.ailment
        expect( m40_record.>>.prescription ).not_to eq m40.prescription
      end
    end

    context "when we don't have an IV column" do
      it "scrambles the encrypted columns and leaves the others alone" do
        d = diary_model_class.new
        d.id      = 44
        d.date    = Date.new(2018,4,14)
        d.heading = "fred"
        d.text    = "sore toe"
        d.create

        record = d.interface.read(44)
        expect( record.>>.date    ).to eq d.date
        expect( record.>>.heading ).not_to eq d.heading
        expect( record.>>.text    ).not_to eq d.text
      end
    end
    
  end # of (Creating a record)


  describe "(reading a record)" do
     
    context "when we have an IV column" do

      before(:each) do
        m = medical_model_class.new
        m.id           = 40
        m.nhs_no       = "123456"
        m.name         = "fred"
        m.ailment      = "sore toe"
        m.prescription = "suck thumb"
        m.create
      end

      it "returns the IV field as encryption_iv" do
        m40 = medical_model_class.new(40).read
        expect( m40.encryption_iv ).not_to be_nil
        expect( m40.encryption_iv ).to eq m40.nonce
      end

      it "decrypts the columns" do
        m40 = medical_model_class.new(40).read
        expect( m40.nhs_no       ).to eq "123456"
        expect( m40.name         ).to eq "fred"
        expect( m40.ailment      ).to eq "sore toe"
        expect( m40.prescription ).to eq "suck thumb"
      end

    end

    context "when we have no IV column" do
       
      before(:each) do
        d = diary_model_class.new
        d.id      = 44
        d.date    = Date.new(2018,4,14)
        d.heading = "fred"
        d.text    = "sore toe"
        d.create
      end

      it "decrypts the columns" do
        d44 = diary_model_class.new(44).read
        expect( d44.date    ).to eq Date.new(2018,4,14)
        expect( d44.heading ).to eq "fred"
        expect( d44.text    ).to eq "sore toe"
      end
    
    end
    
  end # of (reading a record)
  

  context "when we have an IV column" do
    let(:m40) do
      m = medical_model_class.new
      m.id           = 40
      m.nhs_no       = "123456"
      m.name         = "fred"
      m.ailment      = "sore toe"
      m.prescription = "suck thumb"
      m.create
    end

    let(:iv) do
      record = m40.interface.read(40)
      record.>>.nonce
    end

    describe "Model#(encryption_iv field)" do

      it "returns nil for a new model object" do
        m = medical_model_class.new
        m.id = 50

        expect( m.nonce ).to be_nil
      end

      it "returns the nonce for an existing record" do
        expect( m40.nonce ).to eq iv
      end

    end # of Model#(encryption_iv field)

    describe "Model#encryption_iv" do

      it "returns nil for a new model object" do
        m = medical_model_class.new
        m.id = 50

        expect( m.encryption_iv ).to be_nil
      end

      it "returns the nonce for an existing record" do
        expect( m40.encryption_iv ).to eq iv
      end

    end # of Model#encryption_iv

    describe "Model#map_to_interface" do

      it "sets the IV column on create" do
        expect( iv ).not_to be_nil
      end

      it "encrypts only the encryptable columns for the interface" do
        record = m40.map_to_interface
        expect( record.>>.nhs_no       ).to eq "123456"
        expect( record.>>.name         ).to eq encrypt(encryption_key, iv, "fred")
        expect( record.>>.ailment      ).to eq encrypt(encryption_key, iv, "sore toe")
        expect( record.>>.prescription ).to eq encrypt(encryption_key, iv, "suck thumb")
      end
      
      it "raises a sensible exception if an encryption column is non-text" 

    end # of Model#map_to_interface

    describe "Model#map_to_model" do

      it "decrypts only the encryptable columns for the model" do
        m40
        m = medical_model_class.new(40)
        record = m.interface.read(40)
        expect( record.>>.name         ).not_to eq "fred"
        expect( record.>>.ailment      ).not_to eq "sore toe"
        expect( record.>>.prescription ).not_to eq "suck thumb"

        m.read
        expect( m.nhs_no       ).to eq "123456"
        expect( m.name         ).to eq "fred"
        expect( m.ailment      ).to eq "sore toe"
        expect( m.prescription ).to eq "suck thumb"
      end

    end # of Model#map_to_model

  end # of when we have an IV column


  context "when we don't have an IV column" do

    describe "Model#map_to_interface" do

      it "encrypts only the encryptable columns for the interface" do
        d44 = diary_model_class.new
        d44.id      = 44
        d44.date    = Date.new(2018,4,14)
        d44.heading = "fred"
        d44.text    = "sore toe"

        record = d44.map_to_interface

        expect( record.>>.date    ).to eq Date.new(2018,4,14)
        expect( record.>>.heading ).to eq encrypt(encryption_key, "fred")
        expect( record.>>.text    ).to eq encrypt(encryption_key, "sore toe")
      end
      
      it "raises a sensible exception if an encryption column is non-text" 
    
    end # of Model#map_to_interface

    describe "Model#map_to_model" do
       
      it "decrypts only the encryptable columns for the model" do
        d = diary_model_class.new
        d.id      = 44
        d.date    = Date.new(2018,4,14)
        d.heading = "fred"
        d.text    = "sore toe"
        d.create

        d44    = diary_model_class.new(44)
        record = d44.interface.read(44)
        expect( record.>>.heading ).not_to eq "fred"
        expect( record.>>.text    ).not_to eq "sore toe"

        d44.read
        expect( d44.date    ).to eq Date.new(2018,4,14)
        expect( d44.heading ).to eq "fred"
        expect( d44.text    ).to eq "sore toe"
      end
      
    end # of Model#map_to_model
    
    
  end # of when we don't have an IV column


end

