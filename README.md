Introduction
============

Pod4 is not an ORM. No, really it isn't. Because that would be ridiculous.

...okay, it kind of acts a _bit_ like an ORM...

Ah, well. Judge for yourself. Here's a model:

    class CustomerModel < Pod4::Model

      class CustomerInterface < Pod4::PgInterface
        set_table  :customer
        set_id_fld :id
      end

      set_interface CustomerInterface.new(CONN_STRING)

      attr_columns :cust_code, :name, :group
    end

And here's a method that uses the model:

    def change_customer_group(id, group)
      customer = Customer.new(id).read.or_die
      customer.group = group
      customer.update.or_die
    end


Seriously now
-------------
    
Pod4 is a very simple set of classes that sits on top of some other library which gives access to
data -- for example, pg, tds, or Sequel (which _is_ an ORM...) It's relatively easy to get it to
talk to a new sort of data access library, and you're not limited to databases.

It provides a simple, common framework to talk to all these data sources, using model classes which
(to my mind at least) are clean, easy to understand and maintain, using a bare minimum of DSL and
vanilla Ruby inheritance.

This is the central motivation behind the project -- to provide a mechanism that allows for model
classes which actually represent your data to the rest of your code in a way that you are fully in
control of. Because it's your model classes, not the database, which are the canonical
representation of the data.

I don't want the people who maintain my code to have to know the differences between ActiveRecord's
`update` and `update_all`, or Sequel's `dataset[]` and `dataset.where()`.  Pod4::Model has a dozen
or so methods you need to worry about, and six of those are pretty much self-explanatory. Or, you
can inherit from Pod4::BasicModel instead, and do without even that.

I honestly don't think of it as an Object Relational Manager.  I think of it as a Way To Have Nice
Models.

If you are looking for something with all the features of, say, ActiveRecord, then this isn't for
you. I provide basic access to and maintenance of records, with validation. For anything more, you
need to be willing to use a very well established existing DSL within your model code -- SQL.


Thanks
======

This code was developed, by me, during working hours at [James Hall & Co.
Ltd](https://www.jameshall.co.uk/). I'm incredibly greatful that they have permitted me to
open-source it.


Installation
============

    gem install pod4

Of course you will also need to install whatever other gems you need in order to access the data
you want Pod4 to see.  Currently there are interfaces for:

* Sequel (which itself of course talks to all manner of databases)
* Tiny_tds
* Pg
* Nebulous (my own STOMP wrapper/protocol/what-have-you)

(But, you can add your own interfaces. It's not hard.)


A Short Tutorial
================

(Don't Worry About) Octothorpe
------------------------------

Pod4 uses my Octothorpe gem to pass information around. An Octothorpe is basically a Hash, except
the keys are always symbols, and it's read only. 

But you don't really need to know that here. If you mentally substitute "Hash" every time I say
"Octothorpe", you'll be fine.


Model and Interface
-------------------

Note well that we distinguish between 'models' and 'interfaces':

The model represents the data to your application, in the format that makes most sense to your
application: that might be the same format that it is stored in on the database, or it might not.
The model doesn't care about where the data comes from. Models are all subclasses of Pod4::Model
(or Pod4::BasicModel, but we'll leave that alone for now).

An interface encapsulates the connection to whatever is providing the data. It might be a wrapper
for calls to the Sequel ORM, for example. Or it could be a making a series of calls to a set of
Nebulous verbs. It only cares about dealing with the data source, and it is only called by the
model.

An interface is a seperate class, which is defined for each model. There are parent classes for a
number of the sources you will need, but failing that, you can always create one from the ultimate
parent, Pod4::Interface.


Simple Model Usage
------------------

    # find record 14; raise error otherwise. Update and save.
    x = ExampleModel.new(14).read.or_die
    x.two = "new value"
    x.update

    # create a new record from the params hash
    y = ExampleModel.new
    y.set(params)
    y.create 

A model is a class, each instance of which represents a single record. on that instance you can
call the following for basic operation:

* `create` -- tells the data source to store this new "record"
* `read`   -- obtains the "record" from the data source
* `update` -- updates the "record" on the data source
* `delete` -- deletes the "record" on the data source.
* `set`    -- set the column attributes of the object with a hash or Octothorpe
* `to_ot`  -- output an Octothorpe of the object's column attributes
* `alerts` -- return an array of Alerts (which I'll explain later)

(Note that we say "record" not record. The data source might not be a database.  Your model
instance might be represented on the data source as several records, or something else entirely.)

There is one more operation - `list`. Call this on the model class itself, and it will return an
array of model objects that match the criteria you pass. What you can pass to list depends on
your model class (of course); by default it also depends on the interface the model uses. But
normally it should except a hash, like so:

    ExampleModel.list(:one => "a")  #-> Array of ExampleModel where one = "a"

Additionally, you can chain `or_die` onto any model method to get it to raise exceptions if
something is wrong on the model. If you don't want exceptions, you can check the model's
model_status attribute, or just look at the alerts.

Those eight (nine) methods are _all_ the methods given by Pod4::Model that you are normally going
to want to use, outside of the code actually inside your model.


A Simple Model
--------------

Here is the model and interface definition that goes with the above example:

    require 'pod4'
    require 'pod4/pg_interface'
    require 'pg'
    
    class ExampleModel < Pod4::Model

      class ExampleInterface < Pod4::PgInterface
        set_table :example
        set_id_fld :id, autoincrement: true
      end

      set_interface ExampleInterface.new($pg_conn)
      attr_columns :one, :two, :three
    end

In this example we have a model that relies on the Pg gem to talk to a table 'example'. The table
has a primary key field 'id' and columns which correspond to our three attributes one, two and
three.  There is no validation or error control.

Note that we have to require pg_interface and pg seperately. I won't bother to show this in any
more model examples.

### Interface ###

Let's start with the interface definition.  Remember, the interface class is only there to
represent the data source to the model. Yours will most likely be no more complex than the one
above. Since they are only accessed by the model, my preference is to define them in an internal
class, but if that makes you back away slowly waving your hands placatingly, put it in another
file. Pod4 is fine with that.

Inside your interface class you must call some DSLish methods to tell the interface how to talk to
the data. What they are depends on the interface, but the ones for PgInterface are pretty common:

* `set_schema` -- optional -- the name of the schema to find the table in
* `set_table`  -- mandatory -- the name of the database table to use
* `set_id_fld` -- mandatory -- the name of the column that makes the record unique

Actually, _every_ interface defines `set_id_fld`. Instances of a model _must_ be represented by a
single ID field that provides a unique identifier. Pod4 does not care what it's called or what data
type it is -- if you say that's what makes it unique, that's good enough. Additionally you can
specify whether your key autoincrements or not. If you don't say, we assume that it does.

Internally, Interfaces talk the same basic language of list / create / read / update / delete that
models do. Sometimes you might want to add a special interface method for a specific database
operation, but otherwise that's probably going to be it for your Interface definition.

### Model ###

Models have two of their own DSLish methods:

* `set_interface` -- here is where you instantiate your Interface class
* `attr_columns`  -- like `attr_accessor`, but letting the model know to care.

You can see that interfaces are instantiated when the model is required.  Exactly what you need to
pass to the interface to instantiate it depends on the interface. SequelInterface wants the Sequel
DB object; the other interfaces only want connection hashes. 

(If you are finding it annoying to have to, for example, figure out your database connection hash
or get a Sequel DB object _before_ requiring your models, then see "Connections", below.)

Any attributes you define using `attr_columns` are treated specially by Pod4::Model. You get all
the effect of the standard Ruby `attr_accessor` call, but in addition, the attribute will be passed
to and from the interface, and to and from your external code, by the standard model methods.

In addition to the methods above, we have:

* `validate`         -- override this to provide validation
* `map_to_model`     -- controls how the interface sets attributes on the model
* `map_to_interface` -- controls how the model sends data to the interface
* `add_alert`        -- adds an alert to the model

A model also has some built-in attributes of its own:

* `model_id`     -- this is the value of the ID column you set in the interface.
* `model_status` -- one of :error :warning :okay :deleted :unknown

We'll deal with all these below.


Adding Validation
-----------------

Built into the model is an array of alerts (Pod4::Alert) which are messages that have been raised
against the instance of the model class. Each alert can have a type of :error, :warning, :info or
:success. If any alert has a type of :error or :warning, then that is reflected in the model's
`model_status` attribute. A model that has passed validation with no :error or :warning alerts is
status :okay.

(There are two other possible statuses -- models are :unknown when validation has yet to be run, 
and :deleted after a call to delete.)

You can raise alerts yourself, and you normally do so by overriding `validate`.  This method is
called after a read as well as when you write to the database; so that a model object should always
have a model_status reflecting its "correctness" regardless of whether it came from the data source
or your application.

Here's a model with some validation:

    class Customer < Pod4::Model

      class CustomerInterface < Pod4::PgInterface
        set_schema :pod4example
        set_table  :customer
        set_id_fld :id, autoincrement: true
      end

      set_interface CustomerInterface.new($pg_conn)
      attr_columns :cust_code, :name, :group

      def validate(mode)
        super
        return if mode == :delete

        add_alert(:error, :name, "Name cannot be empty") \
          unless @name && @name =~ \^\s*$\

        add_alert(:error, :cust_code, "invalid customer code") \
          unless @cust_code && @cust_code.length == 6

      end

    end

(Note: as a general principal, you should always call super when overriding a method in Pod4 model,
unless you have good reason not to.)

Validation is run on create, read, update and delete.  If the model has a status of :error, then
the validation will fail.  (Probably you do not want this on delete; test the parameter passed
to validate as in the example above).

In passing I should note that validation is _not_ run on list: every record that list returns
should be complete, but the `model_status` will be :unknown because validation has not been run.
(This is partly for the sake of speed.)

You should be aware that validation is not called on `set`, either. Because of that, it's entirely
possible to set a model to an invalid state and not raise any alerts against it until you go to
commit to the database.  If you want to change the state of the model and then validate it before
that, you must call `validate` yourself.


Changine How a Model Represents Data
------------------------------------

Pod4 will do the basic work for you when it comes to data types. integers, decimals, dates and
datatimes should all end up as the right type in the model.  (It depends on the Interface. You're
going to get tired of me saying that, aren't you?) But maybe you want more than that.

Let's imagine you have a database table in PostreSQL with a column called cost that uses the money
type. (This is a terrible idea, by the way.) And you want it to be a `BigDecimal` in the model.
Well, Pod4 won't do that for you -- for all I know someone might have a problem with my requiring
BigDecimal -- but it's not hard to do yourself.

    class Product < Pod4::Model

      class ProductInterface < Pod4::PgInterface
        set_schema :pod4example
        set_table  :product
        set_id_fld :product_id, autoincrement: true
      end

      set_interface ProductInterface.new($pg_conn)
      attr_columns :description, :cost

      def map_to_model(ot)
        super
        @cost = Bigdecimal(@cost)
      end

      def map_to_interface
        super.merge(cost: @cost.to_f)
      end

    end

`map_to_model` gets called when the model wants to write data from the interface on the model; it
takes an Octothorpe from the interface as a parameter. By default it behaves as `set` does.

`map_to_interface` is the opposite: it gets called when the model wants to write data on the
interface from the model. It _returns_ an Octothorpe to the interface. By default it behaves as
`to_ot` does. (Since OTs are read only, you must modify it using merge.)

You might also want to ensure that your data types are honoured when your application updates a
model object; in which case you will need to override `set` as well.

If this seems like a lot of work, take a look at the Pod4::TypeCasting mixin. it will handle it for
you.


Relations
---------

Pod4 does not provide relations. But, I'm not sure that it needs to. Look:

    class BlogPost < Pod4::Model

      class BlogPostInterface < Pod4::PgInterface
        set_table  :blogpost
        set_id_fld :id, autoincrement: true
      end

      set_interface BlogPostInterface.new($conn)
      attr_columns :text

      def comments; Comment.list(post: @id); end
    end


    class Comment < Pod4::Model

      class CommentInterface < Pod4::PgInterface
        set_table  :comment
        set_id_fld :id
      end

      set_interface CommentInterface.new($conn)
      attr_columns :post_id, :text

      def blog_post; BlogPost.new(@post_id).read.or_die; end
    end

So the BlogPost model has a comments method that returns an array of Comments, and the Comments
model has a blog_post method that returns the BlogPost. (You would probably want to add validation
to enforce relational integrity.)

Is this approach inefficient?  Possibly. But if you don't like it, you can always try:


Beyond CRUD (& List)
--------------------

Sooner or later you will want to do something more than Pod4::Model will give you automatically.
There is a perfectly well documented, very popular DSL with lots of examples to solve this problem.
It's called SQL. 

If your interface is connected to a SQL database, it should provide two more methods: `execute` and
`select`.  

    class BlogPost < Pod4::Model

      class BlogPostInterface < Pod4::PgInterface
        set_table  :blogpost
        set_id_fld :id, autoincrement: true
      end

      set_interface BlogPostInterface.new($conn)
      attr_columns :text


      ##
      # return an array of hashes where each comment has the post joined to it
      #
      def post_and_comments
        interface.select( %Q|select *
                               from blogpost b
                               join comments c on(c.post_id = b.id);| )

      end

                              
      ##
      # delete all comments on this post
      #
      def delete_comments
        interface.execute( 
            %Q|delete from comments where post_id = #{@model_id};| )

      end

    end

Neither `execute` nor `select` care about the table or ID field you passed to the interface. They
only run pure SQL. The only difference between them is that select expects to return an array of
results.

To my way of thinking, there is absolutely nothing wrong about using SQL in a model. It will
certainly need revisiting if you change database. But how often does that happen, really?  And if
it ever does, you are likely to need to revisit the effected models anyway...


Connections
-----------

### A Couple Of Wrinkles ###

There are a couple of weird wrinkles in all this which you may or may not have missed.  Wrinkle
one:

    class MyModel < Pod4::Model

      class Interface < Pod4::PgInterface
        set_id_fld :id, autoincrement: true
        set_table  :my_table
      end

      set_interface Interface.new($pgconn)  # <- wrinkle
      attr_columns :one, two, three
    end
      
You _instantiate_ the interface at the point where you _define_ the model.  I admit this is a
little odd. It wasn't a specific design decision on my part; rather it was the cleanest way to get
where I was going. 

In practice this means you need to get your DB connection details from somewhere, maybe create your
Sequel DB object; and only then can you require your models.

Leading on from this, wrinkle two: except when using Sequel (which behaves differently) each
interface has its own connection to the database. This means that your application has (simplifying
a bit here) one database connection for each model class.  So if you have a Customer model and a
Orders model, your application will hold two connections to the database.  All customer enquiries
share a single connection, and all order enquiries share a single connection.

I'm finding that, generally, this scales about right. But if you have a lot of different models and a
database that runs out of connections easily, it might be problematic.

### The Connection Object ###

The solution to both of these wrinkles, if you need one, is to use a Pod4::Connection object:

    #
    # init.rb -- bootup for my project
    #

    # Require libraries
    require "sequel"
    require "pod4"
    require "pod4/sequel_interface"
    require "pod4/connection"

    # require models
    $conn = Pod4::Connection.new(interface: Pod4::SequelInterface)
    require_relative "models/customer"

    # set up database connection
    hash = get_sequel_params
    $conn.data_layer_options = Sequel.connect(hash)

    #############

    #
    # models/customer.rb ( only a part shown)
    #

    class Foo < Pod4::Model
      class Interface < Pod4::SequelInterface
        set_table    :foo
        set_id_field :id, autoincrement: true
      end

      set_interface Interface.new($conn)

TL;DR: the only code that needs to go in the middle of your requires is the line defining a
Connection object; you pass that to the interface instead.  You can set up the parameters
the interface needs and pass them to the connection object afterwards.  

With TdsInterface and PgInterface you can pass the same connection to multiple models and they will
share it.  These interfaces take a Pod4::ConnectionPool instead, but otherwise the code looks
exactly the same as the above example. 

(Technical note: the ConnectionPool object will actually provide multiple connections, one per
thread that uses it.  This satisfies the requirement of the underlying libraries that connections
are not shared between threads, and therefore ensures that Pod4 is more or less thread safe.  You
get this functionality automatically -- if you don't define a ConnectionPool, then the interface
will create one internally. Sequel uses its own thread pool, of course, and we only use the one
Sequel DB object for the whole of Pod4, so it doesn't need any of that. That's why it uses
Pod4::Connection, instead.)


BasicModel
----------

Sometimes your model needs to represent data in a way which is so radically different from the data
source that the whole list, create, read, update, delete thing that Pod4::Model gives you is no
use. 

Pod4::BasicModel gives you:

* `set_interface`
* the `model_id`, `model_status` and `alerts` attributes
* `add_alert`

...and nothing else. But that's enough to make a model, your way, using the methods on the
interface. These are the same CRUDL methods that Pod4::Model provides -- except that on the
interface, the CRUD methods take a record id as a key.

A real world example: at James Hall my intranet system has a User model, where each attribute is a
parameter that controls how the system behaves for that user -- email address, security settings,
etc.  Having one object to represent the user is the most sensible thing.

But I don't want to have to add a column to the database each time I change the intranet system and
add a user parameter. The logical place to change the parameter is in the User model, not in the
database, and certainly not both. So on the database, I have a settings table where the key runs:
userid, setting name.

Here's a simplified version of my User model. This one is read only, but it's hopefully enough to
get the idea:

    class User < Pod4::BasicModel

      class UserInterface < ::Pod4::SequelInterface
        set_table :settings
        set_id_fld :id, autoincrement: false
      end

      # Here we set what settings always exist for a user
      Setting = Struct.new(:setName, :default)

      DefaultSettings = [ Setting.new( :depot, nil ),
                          Setting.new( :store, nil ),
                          Setting.new( :menu,  nil ),
                          Setting.new( :roles, ''  ),
                          Setting.new( :name,  ''  ),
                          Setting.new( :nick,  ''  ),
                          Setting.new( :mail,  nil ) ]

      set_interface UserInterface.new($db)
      attr_reader :userid, :depot, :store, :menu, :roles, :name, :nick, :mail

      class << self
        def keys; DefaultSettings.map{|x| x.setName }; end

        def list
          array = interface.select(%Q|select distinct userid from settings;|)
          array.map {|r| self.new( r[:userid] ).read }
        end
      end # of class << self

      def initialize(userid=nil)
        super(userid)

        self.class.keys.each do |key|
          instance_variable_set( "@#{key}".to_sym, nil )
        end
      end

      def read
        lst = interface.list(userid: @model_id)

        data = lst.each_with_object({}) do |ot,h| 
          h[ot.>>.setname] = ot.>>.setvalue
        end

        @userid = @model_id
        set_merge( Octothorpe.new(data) )
        validate; @model_status = :okay unless @model_status != :unknown

        self
      end

      def to_ot
        hash = self.class.keys.each_with_object({}) do |k,m| 
          m[k] = instance_variable_get("@#{k}".to_sym)
        end

        Octothorpe.new(hash)
      end

      def set_merge(hash)
        self.class.keys.each do |key|
          value = hash[key]
          instance_variable_set( "@#{key}".to_sym, value ) if value
        end
      end

    end


Extensions
----------

There are some mixins that you can use to extend the functionality of Pod4 models.  Have a look
at the comments at the top of the mixin in question if you want details.

* typecasting -- force columns to be a specific ruby type, validation helpers, some encoding stuff
* encrypting  -- encrypt text columns
* tweaking    -- adds DSL commands to support custom methods on the interface.


Gotchas
-------

Some hopefully-not-too-unexpected behaviour:

* If you change attributes on a record, then call #delete or #read on it, we don't warn you that
  your changes are lost.

* If you attempt to update an autoincrement ID field, we don't write that change to the database
  and we don't warn you about that.

* As mentioned above, we only run validate on #create, #read, #update and #delete. So you can
  change the attributes of a record to something invalid without it immediately warning you. (You
  can always run #validate yourself, though.)

* Again, as mentioned above, the array of model instances returned by #list will all be status
  :unknown.  This is because we have run neither #read nor #validate against them.

* I can't stop you writing to `@model_id` or `@model_status` in your model.  I have no idea what
  might happen if you do, but I doubt that it would ever be a good idea.  (In a non-autoincrement
  model, write to your ID field directly instead; `@model_id` will be updated when you call
  #create, #update or of course #read.)
