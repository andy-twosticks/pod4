Things To Do
============

* PG gem fails to cast date fields as date. Nothing we can do about it.

* PG gem raises lots of "please cast this type explicitly" warnings for money,
  numeric types. There is no documentation for how to do this, and apparently
  no-one knows how /O\

* If you subclass Pod4::Model, as you should, fine. If you subclass THAT class,
  it does not inherit columns, interface, etc etc. It looks as if the problem
  is in Model.columns; you can set @columns but that value does not carry over
  to the subclass, which, well, is right; it's a true class variable and we use
  that syntax for precisely that reason. But unfortunate in this case. What we
  need is a class attribute which is inherited like a method, but the actual
  variable is not shared between the parent and the child. I think we need to
  do that manually by initialising @columns to the value from the parent class
  if it exists.

* Sequel_interface has no quoted_table, table, etc methods. We need to rule
  whether these are part of the contract or not. If so, we need to add them to
  the tests (and add them to SequelInterface).

    * As soon as you try to use the selection parameter of list, you are going
      to notice that it doesn't quote the values.  That would be a bug.

* PgInterface works pretty well for the PG gem, but not the pg_jruby gem. We
  need to take a rather more paranoid approach to the thing; how we go about
  adding test coverage for this I have literally no idea...
