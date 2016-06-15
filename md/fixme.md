Things I Wish I Could Do
========================

* TinyTds gem fails to cast date fields as date. Nothing we can do about that,
  AFAICS.

* PG gem raises lots of "please cast this type explicitly" warnings for money,
  numeric types. There is no documentation for how to do this, and apparently
  no-one knows how /O\

* Like an idiot I've made some tidying "raise an error" instance methods .. and
  then called them from class methods.  ::headdesk::


Things To Do
============

* I had a note here on how SequelInterface does not support the table and
  quoted_table variables. Well, these definitely aren't part of the contract:
  how would NebulousInterface support them? But there might be an issue with
  passing selection parameters to SequelInterface.list if the schema is set. We
  need to tie down a test for that and fix it if it exists.

* PgInterface works pretty well for the PG gem, but not the pg_jruby gem. We
  need to take a rather more paranoid approach to the thing; how we go about
  adding test coverage for this I have literally no idea...

* TinyTDS just updated to 1.0 and ... fell over.  We need to work out what's
  going on there.

* Ideally interfaces should support parameterised insertion. Ideally in a
  manner consistent for all interfaces...

* We should have a test suite for jRuby.

