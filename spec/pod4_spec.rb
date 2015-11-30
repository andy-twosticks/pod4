require 'logger'

require 'pod4'
require 'pod4/param'


describe Pod4 do

  # Magically replaces the real Param module
  let(:param) { class_double(Pod4::Param).as_stubbed_const }

  #after(:all) { Param.set(:logger, nil) }


  it 'has a version' do
    expect( Pod4::VERSION ).not_to be_nil
  end
  ##


  describe "Pod4.set_logger" do

    it "calls Param.set" do
      l = Logger.new(STDOUT)
      expect(param).to receive(:set).with(:logger, l)
      Pod4.set_logger(l)
    end

  end
  ##


  describe 'Pod4.logger' do

    it 'returns the logger as set' do
      l = Logger.new(STDOUT)
      Pod4.set_logger(l)

      expect( Pod4.logger ).to eq l
    end

    it 'still works if no-one set the logger' do
      expect{ Pod4.logger }.not_to raise_exception
      expect( Pod4.logger ).to be_a_kind_of Logger
    end

  end
  ##


end
