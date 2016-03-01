require 'logger'
require 'devnull'

require 'pod4/param'
require 'pod4/model'
require 'pod4/alert'



##
# Pod4. Totally not an ORM. Honest.
#
# ...Okay, I admit that it kind of implements the Datamapper pattern to talk to
# data sources and provides a framework for the 'model' part of
# model-view-controller. So in a bad light it might *look* like an ORM. But
# clearly I would be very silly to have written such a thing, so please don't
# suggest that I did.
#
# More seriously: We needed a single consistent approach to handling data from
# Sequel (which really *is* an ORM...) and also from Nebulous (which doesn't
# even talk to a database!). Plus Sequel really only wants to talk to one
# database from one source, which is painful. Plus Sequel's models are pretty
# awful, and we definitely want real models.
#
# So, Pod4, which:
#     * will gather data from absolutely anything. Nebulous, Sequel, Pg,
#       TinyTds, whatever. Add your own on the fly.
#
#     * will allow you to define models which are genuinely represent the data
#       your way, not the way the data source sees it.
#
#     * is hopefully simple and clean; just a very light helper layer with the
#       absolute minimum of magic or surprises for the developer. 
#
# For more information, you should look at the contract Pod4 makes with its
# callers -- you should find all that you need in the classes Pod4::Interface
# and POd4::Model.  Or, read the tests, of course.
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
