TypeCasting
===========

Example
-------

```
require 'pod4'
require 'pod4/someinterface'
require 'pod4/typecasting'

class Foo < Pod4::Model
  include Pod4::TypeCasting

  class Interface < Pod4::SomeInterface
    # blah blah blah
  end

  set_interface Interface.new($stuff)

  attr_columns :name, :issue, :created, :due, :last_update, :completed, :thing

  # Now the meat
  typecast :issue,         as: Integer
  typecast :created, :due, as: Date
  typecast :last_update,   as: Time
  typecast :completed,     as: BigDecimal, ot_as: Float
  typecast :thing,         use: mymethod
end
```

What You Get
------------

### Every attribute named in a typecast gets:

* An accessor. (Probably it already has one, if it is named in attr_columns, but it doesn't have to
  be. Note, though, that we don't add the attribute to the column list and it does not get output
  in to_ot by default.)

* An attempt to force the value to that data type on set().  If the value cannot be coerced, it is
  *untouched*. 

* A second attempt to cast on to_interface(). This time, if the value cannot be coerced, it is set
  to nil.

* if the optional `ot_as` type is set, then we cast a third time in the `to_ot()` method;
  additionally we guard the OT with the base type using Octothorpe.guard. Note that this only
  effects to_ot().

### Additionally the user can call these methods:

* `typecast?(:columnname, value)` returns true if the value can be cast; value defaults to the
  column value if not given.

* `typecast(type, value, strict)` returns a typecast value, or either the original value, or nil if
  strict is `:strict'.  

* `guard(octothorpe)` will set guard conditions for nil values on the given octothorpe, based on
  the attributes typecast knows about.

### The following types will be supported:

* Integer
* BigDecimal
* Float
* Date
* Time
* :boolean

Also: custom typecasting (`use: mymethod`, above). This must accept two parameters: the value, and
an option hash.


What You Don't Get
------------------

Validation. It's entirely up to you to decide how to validate and we won't second guess that.  But
we do provide the `typecast?` method to help.

