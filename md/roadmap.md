Transactions
============

I'd like to support basic transactions because without it we can't really claim to do optimistic
locking properly. And it would be nice to claim that.

Thought I had a solid idea of how to do it without any faffing around, but, it had some holes. Will
have to think again.

But, this is top of my wish list.

For the record, my current thinking: 

    customer.new(4).read.or_die
    customer.transaction do |c|
      c.update(foo: 'bar')
      c.orders.update(foo: 'bar')
    end.or_die

* a method supports_transactions() will control whether the interface does that. sql_helper will
  define it to return true.

* sql_helper will define a sql_transaction method which wraps SQL as a transaction.

* interface methods create() delete() and update now accept an extra parameter, a boolean; if true,
  they will return sql (and values), rather than doing anything. This is defined in Pod4::Interface.

* BasicModel defines @in_transaction = false; @tx_sql = ""; @tx_vals = [].

* When a Model is @in_transaction, the create, delete and update methods pass the extra parameter
  to the corresponding interface methods. The results are accumulated in @tx_sql and @tx_vals.

* the method BasicModel.transaction will:

    * set interface.in_transaction = true, or raise an error if the interface doesn't support them
    * yield a block passing the model instance so that the caller can run methods inside it
    * set in_transaction back to false.
    * call interface.executep( interface._sql_transaction( @tx_sql ), @tx_vals )

Notes:

* We will either have to standardize the execute method or check for it each time?
* Ditto with executep. Ditto with whether an interface supports parameterisation.
* trying to do a transaction across databases will fall over, but, really, no expectation there.
* You can't have a transaction that uses the result of the first half to do the last half.
* You can no longer call select() in a create, as we currently do for some interfaces? This is the
  real problem I am wrestling with -- how to allow a transaction that returns a value from create().


Migrations
==========

This will almost certainly be something crude -- since we don't really control the database
connection in the same way as, say, ActiveRecord -- but I honestly think it's a worthwhile feature.
Just having something that you can version control and run to update a data model is enough,
really.

I'm not yet sure of the least useless way to implement it.  Again, I favour SQL as the DSL.

We will clearly need transactions first, though.

My Current thoughts:

* a migration against a database is on a par with a model but very different. You subclass
  migration and give it an interface, pointing to the table that stores the current migration
  state.  

* The methods in a module are exectute() up() and down() -- the last two call the first one.

* Each instance of a model is stored in a file and contains up and down SQL somehow. Each instance
  has a version number.

* You run a migration by running up or down on your migration class, passing a version?


Connection Object
=================

PgInterface and TdsInterface both take a connection Hash, which is all very well, but it means that
we are running one database connection per model.  Presumably this is a bad idea. :-)

This actually hasn't come up in my own use of Pod4 -- for complex reasons I'm either using
SequelInterface or running transient jobs which start up a couple of models, do some work, and then
stop entirely.

Connection is baked into those interfaces, and interface dependant. So I'm thinking in terms of a
memoising object that stores the connection hash and then gets passed to the interface. When the
interface wants a connection, then it asks the connection object. If the connection object doesn't
have one, then the interface connects, and gives the connection to the connection object.

It's looking as if we don't need this right now. One connection per model might not be as daft as
it seems.


JDBC-SQL interface
==================

For the jdbc-msssqlserver gem.  Doable ... I *think*.

    driver = Java::com.microsoft.sqlserver.jdbc.SQLServerDriver.new
    props = java.util.Properties.new
    props.setProperty("user", "username")
    props.setProperty("password", "password")
    url = 'jdbc:sqlserver://servername;instanceName=instance;databaseName=DbName;'

    conn = driver.connect(url, props)
    #or maybe conn = driver.get_connection(url, "username", "password")

    stmt = conn.create_statement
    sql = %Q|blah;|

    rsS = stmt.execute_query(sql)

    while (rsS.next) do
      veg = Hash.new
      veg["vegName"] = rsS.getObject("name")
      # etc
    end

    stmt.close
    conn.close

    see https://github.com/jruby/jruby/wiki/JDBC


