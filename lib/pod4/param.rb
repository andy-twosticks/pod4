require 'octothorpe'


module Pod4


  module Param
    extend self


    DEFAULTS = { blah: nil,
                 bleh: [] }


    def params
      @params || {}
    end


    def get_all
      Octothorpe.new(params)
    end


  end

end

