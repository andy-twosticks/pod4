Goals we are working towards by adding Connections:

Removing the instantiate-on-require part of Pod4
------------------------------------------------

At least, as much as possible. 

Three things here that make Pod4 harder to use:

1. Instantiating the interface when the model is required

2. In the case of Sequel, instantiating the connection beforehand so we can pass it to the
  interface when we instantiate it.

3. Reading config files or whatever to get the connection parameters to pass to Sequel or the
   interface when we instantiate them.

In the short term we want to provide the option to instantiate a connection object to pass to the
interface instead. The connection object would only need the connection parameters before the model
was used, not required.  

This will probably not include SequelInterface, since that would likely be a breaking change, but
we want this for v1.0.

It's entirely possible that even in 1.0 we will continue to instantiate the interface when we
require the model. But if we only need to pass it an empty connection object, this is not so bad --
we will have eliminated (2) and (3).


Making Pod4 Threadsafe
----------------------

(Once the above is complete.)

To be clear: by threadsafe I mean, only one thread talks to the data source client _at any one
time_.  The problem is messing up the internal state of the client object via a race condition.
That's it. 

Currently this is only an issue if the data source client is not itself threadsafe.  My current
thinking is that Sequel is but Pg _may_ not be.  

The nature of Pod4 is that multiple model objects all talk to the same interface, so if (as is
natural for a web app, for example) those objects are in different threads, then we have multiple
threads talking to the same data source client object.

My solution: Pod4 will hold a pool of connections, and assign a different connection for each
thread it is being run in.

We need a way to test whether we have solved the problem.  One approach that might work: a dummy
interface that logs internally when a CRUD request has started and ends.  If it gets an overlap, we
are not thread safe.


Design Thoughts
---------------

In theory these are not breaking changes. You can still pass a Hash or a Sequel DB object when you
instantiate an Interface and have Pod4 work as it does now; but the changes are so substantial that
I would hate to guarantee continuity of behaviour, so we are treating them as if they are breaking.

We will be releasing this as part of the 1.0 update.

### Pod4::Interface and children ###

* Is still instantiated when the model is required, but we pass it an empty Pod4::Connection, which
  can be created trivially.

* `#new` can now take a Connection object instead of whatever it currently takes. If it is _not_
  given a Connection object, it must create an appropriate one (eg Connection for SequelInterface,
  ConnectionPool for PgInterface) and use that, passing what it has been given as the data layer
  options.

* `#new_connection` must now be defined for each interface, and returns a new DB client object
  that is ready to accept SQL.

* `#close_connection` must now be defined for each interface, and closes the connection somehow.

* No longer stores @client but always asks `Connection#client` for it, instead, passing itself.

* Continues to be the object that knows _how_ to create a client for that interface. Never 
  creates a client by itself, though; rather, it asks Connection to do that.

* Must now make a point of calling `Connection#close` whenever it finishes a database operation
  (except for SequelInterface).

Note that `#new_connection' and '#close_connection' were often defined against an Interface anyway
(or something like them); the change is that they are now a formal part of the interface to
every Pod4::Interface class.


### Pod4::Connection ###

Used when we don't need a connection pool. Internally we use it for SequelInterface and
NebulousInterface.

* Stores a single client object and the Pod4::Interface object that created it.

* `#new` takes a hash. You must provide the class of an interface, for validation purposes. You may
  also provide configuration parameters. 

* `#data_layer_options` sets a Data Layer Option object. (Usually this is the connection hash for
  the data layer library, but Connection doesn't care; it's just holding it to give to the
  Interface.)

* `#client` takes the calling object and returns the client. If it doesn't have one, it
  asks the calling object to create one (passing it the DLO object), and stores it. (In the case of
  Sequel, the DLO object is actually the client object, which we've created outside Pod4; but
  Connection neither knows or cares about this.)

* `#close` closes the client (we implement this by asking the interface to close it).

### Pod4::ConnectionPool ###

Inherits from `Pod4::Connection`. Used for most interfaces.

* stores a pool of multiple clients. Each connection can have a single thread ID assigned to it.

* `#new` has a configuration parameter: maximum number of clients in the pool. Without this
  parameter, there is no limit.

* `#client` returns the client assigned to the current thread (`Thread.current.object_id`) in
  the pool; or failing that picks a free client from the pool; or failing that, it asks the
  interface for a new client, as in Pod4::Connection. It makes any changes the pool in a Mutex, so
  that no other thread asking for a client will get the same one.

* `#close` de-assigns the client for the current thread, making that client free to be assigned to
  another thread.


New Boot Sequence
-----------------

Create a Connection; require everything; give the connection a DLO.

```
# pre-requires
$conn = Pod4:Connection.new(interface: Pod4::PgInterface, max_clients: 8)

# ...

# Example model
class Foo < Pod4::Model
  class Interface < Pod4::PgInterface
    set_table :foo
    set_id_field :id
  end

  set_interface Interface.new($conn)
# ...

# post-requires
connect_hash = get_from_yaml
$conn.data_layer_options connect_hash
```


