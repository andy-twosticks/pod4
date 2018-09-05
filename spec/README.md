Some Notes On Testing
=====================

Some of the interface tests require an actual database to run.  

If you want to run the whole test suite you will have to configure
spec/fixtures/database.yaml so that you can connect to both an SQL Server
database and a Postgres database.  

In each case the database name you need to use is hardcoded: pod4_test. (Pod4
assumes that the schema names can be hardcoded, and since we create and wipe
tables in these tests, you should really have a seperate database for them
anyway.)

