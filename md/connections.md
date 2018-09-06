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

To be clear: by threadsafe I mean, only one thread talks to the data source client _at any one
time_.  The problem is messing up the internal state of the client object via a race condition.
That's it. 

Currently this is only an issue if the data source client is not itself threadsafe.  My current
thinking is that Sequel is but Pg _may_ not be.  

The nature of Pod4 is that multiple model objects all talk to the same interface, so if (as is
natural for a web app, for example) those objects are in different threads, then we have multiple
threads talking to the same data source client object.

I think we may end up using the Connection Pool gem to solve this problem: each connection in the
pool is served in a Mutex and in it's own thread.  But there is no facility in the Gem for
restarting a terminated connection; we would have to work around that.

Alternatively we could just apply our own Mutex system to ensure access to the client was locked.
But at this point I would rather not; Connection Pool is a small gem and a suitable dependancy to
add.

We need a way to test whether we have solved the problem.  One approach that might work: a dummy
interface that logs internally when a CRUD request has started and ends.  If it gets an overlap, we
are not thread safe.
