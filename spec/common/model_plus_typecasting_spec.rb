require "octothorpe"
require "bigdecimal"

require "pod4"
require "pod4/typecasting"
require "pod4/null_interface"


describe "ProductModel" do

  let(:product_model_class) do
    Class.new Pod4::Model do
      include Pod4::TypeCasting
      force_encoding Encoding::ISO_8859_1   # I assume we are running as UTF8 here
      attr_columns :id, :code, :product, :price
      set_interface NullInterface.new(:id, :code, :product, :price, [])
    end
  end

  let(:customer_model_class) do
    Class.new Pod4::Model do
      include Pod4::TypeCasting
      attr_columns :id, :code, :band, :sales, :created, :yrstart, :flag, :foo, :bar
      typecast :band,     as: Integer, strict: true
      typecast :sales,    as: BigDecimal, ot_as: Float, strict: true
      typecast :created,  as: Time
      typecast :yrstart,  as: Date
      typecast :flag,     as: :boolean
      typecast :foo,     use: :mycast, bar: 42
      typecast :bar,      as: Float 
      set_interface NullInterface.new( :id, :code, :band, :sales, :created, :yrstart, 
                                       :flag, :foo, :bar, [] )

      def mycast(value, opts); end
    end
  end

  let(:product_records) do
    [ {id: 10, code: 'aa1', product: 'beans',   price: 1.23},
      {id: 20, code: 'bb1', product: 'pears',   price: 2.34},
      {id: 30, code: 'cc1', product: 'soap',    price: 3.45},
      {id: 40, code: 'cc2', product: 'matches', price: 4.56} ]
  end

  let(:product_model) do
    m = product_model_class.new(30)

    allow( m.interface ).to receive(:read).
      and_return( Octothorpe.new(product_records[2]) )

    m.read.or_die
  end


  ########


  describe "Model.force_encoding" do

    it "requires an encoding" do
      expect( product_model_class ).to respond_to(:force_encoding).with(1).argument

      expect{ product_model_class.force_encoding('foo') }.to raise_exception Pod4Error

      # Cheating here: this has to be the same as above or other tests will
      # fail...
      expect{ product_model_class.force_encoding(Encoding::ISO_8859_1) }.
        not_to raise_exception

    end

    it "sets the encoding to be returned by Model.encoding" do
      expect{ product_model_class.encoding }.not_to raise_exception
      expect( product_model_class.encoding ).to eq(Encoding::ISO_8859_1)
    end

  end # of Model.force_encoding


  describe "Model.typecast" do

    let(:customer_model_bad1_class) do
      Class.new Pod4::Model do
        include Pod4::TypeCasting
        attr_columns :id, :foo
        typecast :foo, blarg: Integer
        set_interface NullInterface.new(:id, :foo, [])
      end
    end

    let(:customer_model_bad2_class) do
      Class.new Pod4::Model do
        include Pod4::TypeCasting
        attr_columns :id, :foo
        typecast :foo, as: Octothorpe
        set_interface NullInterface.new(:id, :foo, [])
      end
    end

    let(:customer_model_bad3_class) do
      Class.new Pod4::Model do
        include Pod4::TypeCasting
        attr_columns :id, :foo
        typecast :bar, as: Integer
        set_interface NullInterface.new(:id, :foo, [])
      end
    end

    it "requires either the 'as:' option or the 'use:' option" do
      expect{ customer_model_bad1_class }.to raise_exception Pod4::Pod4Error
    end

    it "raises an error for an unknown typecast type" do
      expect{ customer_model_bad2_class }.to raise_exception Pod4::Pod4Error
    end

    it "raises an error for an unknown column" do
      expect{ customer_model_bad3_class }.to raise_exception Pod4::Pod4Error
    end

  end # of Model.typecast


  describe "Model.typecasts" do

    it "is a hash of hashes" do
      expect( customer_model_class.typecasts        ).to be_a Hash
      expect( customer_model_class.typecasts.values ).to all(be_a Hash)
    end

    it "has a key for each column typecast" do
      expect( customer_model_class.typecasts.keys ).
        to match_array(%i|band sales created yrstart flag foo bar|)

    end

    it "stores the given options of each column as the value" do
      expect( customer_model_class.typecasts[:band] ).to eq(as: Integer, strict: true)

      expect( customer_model_class.typecasts[:sales] ).
        to eq(as: BigDecimal, ot_as: Float, strict: true)

      expect( customer_model_class.typecasts[:created] ).to eq(as: Time)
      expect( customer_model_class.typecasts[:yrstart] ).to eq(as: Date)
      expect( customer_model_class.typecasts[:foo]     ).to eq(use: :mycast, bar: 42)
      expect( customer_model_class.typecasts[:bar]     ).to eq(as: Float)
    end

  end # of Model.typecasts
  
  
  describe "#map_to_model" do

    it "forces each string to map to the given encoding" do
      # map_to_model has already happened at this point. No matter.
      ot = product_model.to_ot
      expect( ot.>>.id ).to eq 30
      expect( ot.>>.price ).to eq 3.45
      expect( ot.>>.code.encoding ).to eq Encoding::ISO_8859_1
      expect( ot.>>.product.encoding ).to eq Encoding::ISO_8859_1
    end

  end


  describe "#set" do

    it "typecasts strings to whatever" do
      c = customer_model_class.new
      c.set( id:      77,
             code:    "seven",
             band:    "7",
             sales:   "12.34",
             created: "2018-01-01 12:34",
             yrstart: "2018-01-02",
             flag:    "true",
             bar:     "34.56" )
      
      expect( c.id      ).to eq 77
      expect( c.code    ).to eq "seven"
      expect( c.band    ).to eq 7
      expect( c.sales   ).to eq 12.34
      expect( c.created ).to eq Time.parse("2018-01-01 12:34")
      expect( c.yrstart ).to eq Date.parse("2018-01-02")
      expect( c.flag    ).to eq true
      expect( c.bar     ).to eq 34.56
    end

    it "allows the attribute to be nil" do
      c = customer_model_class.new
      c.set( id:      11,
             code:    "foo",
             band:    nil,
             sales:   nil,
             created: nil,
             yrstart: nil,
             flag:    nil,
             bar:     nil )

      expect( c.code    ).to eq "foo"
      expect( c.band    ).to eq nil
      expect( c.sales   ).to eq nil
      expect( c.created ).to eq nil
      expect( c.yrstart ).to eq nil
      expect( c.flag    ).to eq nil
      expect( c.bar     ).to eq nil
    end

    # Note: we cover typecasting more thoroughly in Model#typecast

    it "leaves the column alone if it can't typecast (with strict off)" do
      c = customer_model_class.new
      c.set( created: "bloob",
             yrstart: "flarg",
             flag:    "blobe",
             bar:     "xing" )

      expect( c.created ).to eq "bloob"
      expect( c.yrstart ).to eq "flarg"
      expect( c.flag    ).to eq "blobe"
      expect( c.bar     ).to eq "xing"
    end

    it "sets the column to nil if it can't typecast (with strict on)" do
      c = customer_model_class.new
      c.set( band:  "bloob",
             sales: "flarg" )

      expect( c.created ).to eq nil
      expect( c.yrstart ).to eq nil
    end

    it "calls the use method to get a typecast when the use option is given" do
      c = customer_model_class.new
      expect( c ).to receive(:mycast).with("12345", {use: :mycast, bar: 42} )

      c.set( foo: "12345" )
    end

  end # of #set


  describe "#map_to_interface" do

    it "typecasts strings to whatever" do
      c = customer_model_class.new
      c.id      = 11
      c.code    = "foo"
      c.band    = "12"
      c.sales   = "98.76"
      c.created = "2018-04-04 11:59"
      c.yrstart = "2018-01-09"
      c.flag    = "true"
      c.bar     = "87.65"
      c.create

      record = customer_model_class.interface.read(11)
      expect( record.>>.code    ).to eq "foo"
      expect( record.>>.band    ).to eq 12
      expect( record.>>.sales   ).to eq BigDecimal.new("98.76")
      expect( record.>>.created ).to eq Time.parse("2018-04-04 11:59")
      expect( record.>>.yrstart ).to eq Date.parse("2018-01-09")
      expect( record.>>.flag    ).to eq true
      expect( record.>>.bar     ).to eq 87.65
    end

    it "allows the attribute to be nil" do
      c = customer_model_class.new
      c.id      = 11
      c.code    = "foo"
      c.band    = nil
      c.sales   = nil
      c.created = nil
      c.yrstart = nil
      c.flag    = nil
      c.bar     = nil
      c.create

      record = customer_model_class.interface.read(11)
      expect( record.>>.code    ).to eq "foo"
      expect( record.>>.band    ).to eq nil
      expect( record.>>.sales   ).to eq nil
      expect( record.>>.created ).to eq nil
      expect( record.>>.yrstart ).to eq nil
      expect( record.>>.flag    ).to eq nil
      expect( record.>>.bar     ).to eq nil
    end

    # Note: we cover typecasting more thoroughly in Model#typecast

    it "sets the column to nil if it can't typecast" do
      c = customer_model_class.new
      c.id      = 22
      c.code    = "bar"
      c.band    = "bloob"
      c.sales   = "flarg"
      c.created = "flam"
      c.yrstart = "glarb"
      c.create

      record = customer_model_class.interface.read(22)
      expect( record.>>.code    ).to eq "bar"
      expect( record.>>.band    ).to eq nil
      expect( record.>>.sales   ).to eq nil
      expect( record.>>.created ).to eq nil
      expect( record.>>.yrstart ).to eq nil
    end
    
    it "calls the use method to get a typecast when the use option is given" do
      c = customer_model_class.new
      # Note that we have gained the strict option automatically since we're in map_to_interface
      expect( c ).to receive(:mycast).with("12345", {use: :mycast, bar: 42, strict: true} )

      c.id   = 33
      c.code = "baz"
      c.foo  = "12345"
      c.create
    end
     
  end # of #map_to_interface"


  describe "#to_ot" do
     
    it "casts any columns with the ot_as option as per that option" do
      c1 = customer_model_class.new
      c1.sales = BigDecimal.new("45.67")
      ot = c1.to_ot
      expect( ot.>>.sales ).to be_a Float
      expect( ot.>>.sales ).to eq 45.67

      c2 = customer_model_class.new
      c2.sales = "67.89"
      ot = c2.to_ot
      expect( ot.>>.sales ).to be_a Float
      expect( ot.>>.sales ).to eq 67.89
    end

    it "sets guard on any columns with the to_ot option" do
      c = customer_model_class.new
      c.sales = nil
      ot = c.to_ot

      expect( ot.>>.sales ).to be_a Float
    end

  end # of #to_ot


  describe "#typecast" do
    let(:cmodel) { customer_model_class.new }
     
    it "typecasts strings to any type" do
      expect( cmodel.typecast(Integer,    "123")            ).to eq 123
      expect( cmodel.typecast(Float,      "23.45")          ).to eq 23.45
      expect( cmodel.typecast(BigDecimal, "34.56")          ).to eq BigDecimal.new("34.56")
      expect( cmodel.typecast(Date,       "2018-01-01")     ).to eq Date.parse("2018-01-01")
      expect( cmodel.typecast(Time,       "2018-02-02 14:56") ).to eq Time.parse("2018-02-02 14:56")
      expect( cmodel.typecast(:boolean,   "true")             ).to eq true
      expect( cmodel.typecast(:boolean,   "false")            ).to eq false
    end

    it "typecasts Integer and BigDecimal to Float" do
      expect( cmodel.typecast(Float, 12) ).to be_a Float
      expect( cmodel.typecast(Float, 12) ).to eq 12.0

      expect( cmodel.typecast(Float, BigDecimal.new("12.34")) ).to be_a Float
      expect( cmodel.typecast(Float, BigDecimal.new("12.34")) ).to eq 12.34
    end
    
    it "typecasts Integer and Float to BigDecimal" do
      expect( cmodel.typecast(BigDecimal, 12) ).to be_a BigDecimal
      expect( cmodel.typecast(BigDecimal, 12) ).to eq BigDecimal.new("12.0")

      expect( cmodel.typecast(BigDecimal, 12.34) ).to be_a BigDecimal
      expect( cmodel.typecast(BigDecimal, 12.34) ).to eq BigDecimal.new("12.34")
    end


    it "typecasts reasonably true values to true" do
      %w|true TRUE t T on ON yes YES 1|.each do |x|
        expect( cmodel.typecast(:boolean, x) ).to eq true
      end
    end

    it "typecasts reasonably false values to false" do
      %w|false FALSE f F off OFF no NO 0|.each do |x|
        expect( cmodel.typecast(:boolean, x) ).to eq false
      end
    end

    it "typecasts date to time" do
      expect( cmodel.typecast(Time, Date.parse("2018-01-01")) ).to eq Time.parse("2018-01-01 00:00")
    end

    it "returns the original value if the value is bad and strict is not set" do
      expect( cmodel.typecast(Integer,    12.34)              ).to eq 12.34
      expect( cmodel.typecast(Float,      "blarg")            ).to eq "blarg"
      expect( cmodel.typecast(BigDecimal, "floob")            ).to eq "floob"
      expect( cmodel.typecast(Date,       "2018-99-01")       ).to eq "2018-99-01"
      expect( cmodel.typecast(Time,       "2018-02-02 98:76") ).to eq "2018-02-02 98:76"
      expect( cmodel.typecast(:boolean,   "maybe")            ).to eq "maybe"
    end

    it "returns nil if the value is bad and strict is set" do
      expect( cmodel.typecast(Integer,    12.34,              strict: true) ).to be_nil
      expect( cmodel.typecast(Float,      "blarg",            strict: true) ).to be_nil
      expect( cmodel.typecast(BigDecimal, "floob",            strict: true) ).to be_nil
      expect( cmodel.typecast(Date,       "2018-99-01",       strict: true) ).to be_nil
      expect( cmodel.typecast(Time,       "2018-02-02 98:76", strict: true) ).to be_nil
      expect( cmodel.typecast(:boolean,   "maybe",            strict: true) ).to be_nil
    end

    it "will not cast a float or a BigDecimal to an Integer" do
      expect( cmodel.typecast(Integer, 12.34,                   strict: true) ).to eq nil
      expect( cmodel.typecast(Integer, BigDecimal.new("12.34"), strict: true) ).to eq nil
    end
    
    it "will not cast a Time to a Date" do
      expect( cmodel.typecast(Date, Time.now, strict: true) ).to eq nil
    end

  end # of #typecast


  describe "#typecast?" do
    let(:cmodel) { customer_model_class.new }

    it "returns true if the value can be cast to the type" do
      expect( cmodel.typecast?(:band,    123)                            ).to eq true
      expect( cmodel.typecast?(:bar,     23.45)                          ).to eq true
      expect( cmodel.typecast?(:sales,   BigDecimal.new("34.56"))        ).to eq true
      expect( cmodel.typecast?(:created, Time.parse("2018-02-02 14:56")) ).to eq true
      expect( cmodel.typecast?(:yrstart, Date.parse("2018-01-01"))       ).to eq true
      expect( cmodel.typecast?(:flag,    true)                           ).to eq true
      expect( cmodel.typecast?(:flag,    false)                          ).to eq true
    end

    it "returns false if the value cannot be cast to the type" do
      expect( cmodel.typecast?(:band,    123.45)                   ).to eq false
      expect( cmodel.typecast?(:bar,     "floob")                  ).to eq false
      expect( cmodel.typecast?(:sales,   "glarn")                  ).to eq false
      expect( cmodel.typecast?(:created, "bloing")                 ).to eq false
      expect( cmodel.typecast?(:yrstart, Time.parse("2018-02-02")) ).to eq false
      expect( cmodel.typecast?(:flag,    "blarg")                  ).to eq false
    end

    it "uses the actual value of the attribute if a value is not given" do
      cmodel.set( id:      88,
                  band:    123,
                  bar:     23.45,
                  sales:   "34.56",
                  created: "2018-01-06",
                  yrstart: "2018-01-07 11:59",
                  flag:    true )

      expect( cmodel.typecast?(:band)    ).to eq true
      expect( cmodel.typecast?(:bar)     ).to eq true
      expect( cmodel.typecast?(:sales)   ).to eq true
      expect( cmodel.typecast?(:created) ).to eq true
      expect( cmodel.typecast?(:yrstart) ).to eq true
      expect( cmodel.typecast?(:flag)    ).to eq true
    end
     
  end # of #typecast?


  describe "#guard" do
    let(:cmodel) { customer_model_class.new }

    it "sets a guard clause on the given OT for each typecast 'column'" do
      ot  = Octothorpe.new( band:    nil,
                            sales:   nil, 
                            created: nil,
                            yrstart: nil,
                            flag:    nil,
                            bar:     nil,
                            baz:     nil )

      ot2 = cmodel.guard(ot)
      expect( ot.>>.band    ).to be_an Integer
      expect( ot.>>.sales   ).to be_a Float # not a BigDecimal, since it has ot_as set
      expect( ot.>>.created ).to be_a Time
      expect( ot.>>.yrstart ).to be_a Date
      expect( ot.>>.flag    ).to eq false
      expect( ot.>>.bar     ).to be_a Float
      expect( ot.>>.baz     ).to be_nil  # since it's not a column
    end
     
  end # of #guard
  
  
end

