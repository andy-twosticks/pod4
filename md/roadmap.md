Connection Object
=================

PgInterface and TdsInterface both take a connection Hash, which is all very
well, but it means that we are running one database connection per model.
Presumably this is a bad idea. :-)

This actually hasn't come up in my own use of Pod4 -- for complex reasons I'm
either using SequelInterface or running transient jobs which start up a couple
of models, do some work, and then stop entirely -- but it _is_ rather silly.

Connection is baked into those interfaces, and interface dependant. So I'm
thinking in terms of a memoising object that stores the connection hash and
then gets passed to the interface. When the interface wants a connection, then
it asks the connection object. If the connection object doesn't have one, then
the interface connects, and gives the connection to the connection object.

It's looking as if we don't need this right now. One connection per model might not be as daft as
it seems.


Transactions
============

We really need this, because without it we can't even pretend to be doing
proper pessimistic locking.

I've got a pretty solid idea for a nice, simple way to make this happen. It
will be in place soon.  

...I did. Needs more thought. Not soon after all.


Migrations
==========

This will almost certainly be something crude -- since we don't really control
the database connection in the same way as, say, ActiveRecord -- but I honestly
think it's a worthwhile feature.  Just having something that you can version
control and run to update a data model is enough, really.

I'm not yet sure of the least useless way to implement it.  Again, I favour SQL
as the DSL.


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


SQL Injection Projection
========================

We need this.  I want to abstract out all the common SQL for interfaces to a helper mixin, then
have the interfaces call whatever methods their data source provides to insert values into SQL with
placeholders.  We fall back to doing this ourselves, which is considerably less secure, but even so
better than what we have now.

Can't really claim to be generally usable without this functionality.

