require "octothorpe"
require "bigdecimal"

require "pod4"
require "pod4/tweaking"
require "pod4/interface"


describe "(Model plus Tweaking)" do

# ## 
# # I can't use NullInterface this time because I need to define a custom method on the interface.
# # But I'm _only_ calling that custom method, and there is nothing to say that the custom method
# # actually has to talk to a database...
# #
# let(:customer_interface_class) do
#   Class.new Pod4::Interface do
#     
#     def my_list(*args)
#     end
#   end
# end

  let(:customer_model_class) do
    Class.new Pod4::Model do
      include Pod4::Tweaking

      class MyInterface < Pod4::Interface
        attr_writer :response

        # stuff that lets us fake being an interface
        def initialize;      end
        def id_fld;     :id; end

        def test;  end # something we can use to test attr_columns method
        def thing; end # there's already a method called this on the model

        # main test method; responds with whatever we want it to
        def my_list(*args)
          @response
        end
      end

      attr_columns    :id, :code, :band
      set_interface   MyInterface.new
      set_custom_list :my_list

      def thing; end  

    end
  end


  describe "Model.set_custom_list" do

    it "requires the name of a method" do
      expect{ customer_model_class.set_custom_list()         }.to raise_error ArgumentError
      expect{ customer_model_class.set_custom_list(:test) }.not_to raise_error
    end

    it "raises an ArgumentError if the method does not exist on the interface" do
      expect{ customer_model_class.set_custom_list(:nope) }.to raise_error ArgumentError
    end

    it "raises an ArgumentError if the method already exists on the model" do
      expect{ customer_model_class.set_custom_list(:thing) }.to raise_error ArgumentError
    end

    it "creates the corresponding method on the model class" do
      expect( customer_model_class ).to respond_to :my_list
    end 

  end # of Model.set_custom_list


  describe "(custom method on model)" do

    it "passes the arguments given it through to the interface method of the same name" do
      expect( customer_model_class.interface )
        .to receive(:my_list).with(:foo, 1, "bar")
        .and_call_original

      customer_model_class.interface.response = []
      customer_model_class.my_list(:foo, 1, "bar")
    end

    it "raises Pod4Error if the return value is not an Array" do
      customer_model_class.interface.response = :nope
      expect{ customer_model_class.my_list(:foo) }.to raise_error(Pod4Error, /array/i)
    end

    it "raises Pod4Error if the return value is not an Array of Octothorpe/Hash" do
      customer_model_class.interface.response = [:nope]
      expect{ customer_model_class.my_list }.to raise_error(Pod4Error, /hash|record/i)
    end

    it "raises Pod4Error if any of the returned Octothorpe/Hashes are missing the ID field" do
      customer_model_class.interface.response = [{id: 1, code: "one"}, {code: 2}]
      expect{ customer_model_class.my_list }.to raise_error(Pod4Error, /ID/i)
    end

    it "returns an empty array if the interface method returns an empty array" do
      customer_model_class.interface.response = []
      expect{ customer_model_class.my_list }.not_to raise_error
      expect( customer_model_class.my_list ).to eq([])
    end

    it "returns an array of model instances based on the results of the interface method" do
      rows = [ {id: 1, code: "one"},
               {id: 3, code: "three"},
               {id: 5, code: "five", band: 12} ]

      customer_model_class.interface.response = rows
      list = customer_model_class.my_list

      expect( list ).to be_an Array
      expect( list ).to all( be_a customer_model_class )
      expect( list.map(&:id)   ).to match_array( rows.map{|x| x[:id]} )
      expect( list.map(&:code) ).to match_array( rows.map{|x| x[:code]} )
      expect( list.find{|x| x.id == 5}.band ).to eq 12
    end


  end # of (custom method on model)
  
  
end

