A list of breaking / major changes by version.

1.0
===

Interfaces Can Now Note If Their ID Autoincrements
--------------------------------------------------

Autoincrement defaults to true if missing. So any models without auto-incrementing keys will need
to change to specifically name them as such.

You can now add the id field to `attr_columns` even if the ID field autoincrements. Which means
that you can refer to the id field by name as an attribute instead of using `@model_id`, if you
want.

Some minor changes that arise from this:

* #to_ot now always includes the ID field, whether or not it is named in `attr_columns`.

* If you manually update the ID field even though autoincrement is true, that change will not be
  stored in the database / whatever. We don't pass that on.

* If you change the ID field in a non-autoincrement model, `@model_id` is now updated to reflect
  that when you call #update.  (This was not true before 1.0.)



Connection Objects
------------------

This is technically not a breaking change. No existing code needs to be rewritten; interfaces
create connection objects for you if you don't use them.  But, this is a really big change
internally, and as such I would be surprised if it didn't effect existing < 1.0 code.

This counts double if you use PgInterface and TdsInterface, since these are now being served one
connection per thread and are finally really threadsafe.



NullInterface
-------------

The behaviour of NullInterface has changed.  Prior to 1.0 it did not simulate an auto-incrementing
ID field.  Now it does, and that behaviour is the default.

Existing code that assumes the previous behaviour should be fixed by setting the id_ai attribute to
false:

```
ifce = NullInterface.new(:code, :name, [])
ifce.id_ai = false
set_interface ifce
```



DSL To Declare a Custom List Method
-----------------------------------

This is provided by the new Tweaking mixin, so it's not a breaking change.



Model Status :empty
-------------------

This has been renamed to :unknown to reflect that it is also the status of objects created by #list;
:unknown means that validation has not been run yet. This definitely counts as a breaking change,
although you would only be effected if you were testing for :empty in a model...

