require 'logger'
require 'devnull'

require_relative 'pod4/param'
require_relative 'pod4/basic_model'
require_relative 'pod4/model'
require_relative 'pod4/alert'



##
# Pod4, which:
#
# * will gather data from absolutely anything. Nebulous, Sequel, Pg, TinyTds, whatever. Add your
#   own on the fly.
#
# * will allow you to define models which are genuinely represent the data your way, not the way
#   the data source sees it.
#
# * is hopefully simple and clean; just a very light helper layer with the absolute minimum of
#   magic or surprises for the developer. 
#
# For more information:
# 
# * There is a short tutorial in the readme.
#
# * you should look at the contract Pod4 makes with its callers -- you should find all that you
#   need in the classes Pod4::Interface and Pod4::Model. 
#
# * Or, read the tests, of course.
#
module Pod4


  ##
  # If you have a logger instance, set it here to have Pod4 models and
  # interfaces write to it.
  #
  def self.set_logger(instance)
    Param.set(:logger, instance)
  end


  ##
  # Return a logger instance if you set one using set_logger.
  # Otherwise, return a logger instance that points to a DevNull IO object.
  #
  def self.logger
    Param.get(:logger) || Logger.new( DevNull.new )
  end


end
