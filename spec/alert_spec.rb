require 'pod4/alert'


describe Alert do

  let(:err) { StandardError.new('whoa') }


  describe '#new' do

    it 'requires a type of error, warning, info or success; and a message' do
      expect{ Alert.new        }.to raise_exception ArgumentError
      expect{ Alert.new(nil)   }.to raise_exception ArgumentError
      expect{ Alert.new('foo') }.to raise_exception ArgumentError
      
      [:baz, :werning, nil, :note, :debug].each do |badType|
        expect{ Alert.new(badType, 'foo') }.
          to raise_exception(ArgumentError), "Alert.new(#{badType.inspect}...)"

      end

      [:error, :warning, :info, 'success', 'error'].each do |type|
        expect{ Alert.new(type, 'foo') }.
          not_to raise_exception, "Alert.new(#{type.inspect}...)"

      end

    end

    it 'allows the message to be a string' do
      expect{ Alert.new(:warning, 'foo') }.not_to raise_exception
    end

    it 'allows the message to be an exception' do
      expect{ Alert.new(:error, err) }.not_to raise_exception
    end

    it 'allows entry of a field name' do
      expect{ Alert.new(:success, 'foo', 'bar') }.not_to raise_exception
    end

  end
  ##

  
  describe '#type' do

    it 'reflects the type passed to #new' do
      expect( Alert.new(:info, 'foo').type  ).to eq :info
      expect( Alert.new('info', 'foo').type ).to eq :info
    end

  end
  ##


  describe '#message' do

    let(:al1) { Alert.new(:info, 'foo') }
    let(:al2) { Alert.new(:info, err)   }

    it 'reflects the message passed to #new' do
      expect( al1.message ).to eq 'foo'
      expect( al2.message ).to eq 'whoa'
    end

    it 'allows you to change it' do
      al1.message = "one"; al2.message = "two"

      expect( al1.message ).to eq 'one'
      expect( al2.message ).to eq 'two'
    end

  end
  ##


  describe '#field' do

    it 'defaults to nil' do
      expect( Alert.new(:error, 'baz').field ).to be_nil
    end

    it 'reflects the field passed to #new' do
      expect( Alert.new(:info, 'fld1', 'foo').field ).to eq :fld1
    end

    it 'allows you to change it' do
      al = Alert.new(:success, :boris, 'foo')
      al.field = :yuri

      expect( al.field ).to eq :yuri
    end

  end
  ##


  describe '#exception' do

    it 'defaults to nil' do
      expect( Alert.new('warning', 'one').exception ).to be_nil
    end

    it 'reflects the exception passed to #new' do
      expect( Alert.new(:info, err).exception ).to eq err
    end

  end
  ##



  describe '#bootstrap_class' do

    it 'outputs the bootstrap class name for the alert type' do
      h = { error:   'alert-danger',
            warning: 'alert-warning',
            info:    'alert-info',
            success: 'alert-success' }

      h.each do |q,a|
        expect( Alert.new(q, 'foo').bootstrap_class ).
          to eq(a), "Alert.new(#{q.inspect}...) = #{a.inspect}"

      end

    end

  end
  ##


  context 'when collected in an array' do

    it 'orders itself by severity of type' do
      arr = []
      arr << Alert.new(:warning, 'one')
      arr << Alert.new(:error,   'two')
      arr << Alert.new(:info,    'three')
      arr << Alert.new(:success, 'four')

      expect( arr.sort.map{|a| a.type } ).
        to eq([:error,:warning,:info,:success])

    end

  end
  ##

end

