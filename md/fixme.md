Things I Wish I Could Do
========================

* TinyTds gem fails to cast date fields as date. Nothing we can do about that,
  AFAICS.


Things To Do
============

* I had a note here on how SequelInterface does not support the table and
  quoted_table variables. Well, these definitely aren't part of the contract:
  how would NebulousInterface support them? But there might be an issue with
  passing selection parameters to SequelInterface.list if the schema is set. We
  need to tie down a test for that and fix it if it exists.

* TinyTDS just updated to 1.0 and ... fell over.  We need to work out what's
  going on there.

* Ideally interfaces should support parameterised insertion. Ideally in a
  manner consistent for all interfaces...

