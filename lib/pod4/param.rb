require 'octothorpe'


module Pod4


  ##
  # This module implements the singleton pattern and is used internally to
  # store parameters passed to it from outside of Pod4
  #
  module Param
    extend self


    def params; @params ||= {}; end

    def set(p,v); params[p.to_s.to_sym] = v; end

    def get(p); params[p.to_s.to_sym]; end

    def get_all; Octothorpe.new(params.dup); end

    def reset; @params = {}; end


  end

end

