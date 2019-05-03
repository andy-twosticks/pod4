Other changes planned for 1.0 release
=====================================

Interfaces can now specifically note if their ID autoincrements
---------------------------------------------------------------

```
class Foo < Pod4::Model
  class Interface < Pod4::SequelInterface
    set_table :foo
    set_id_field :id, autoincrement: true
  end
  
  # ...
```

Autoincrement defaults to true if missing. This should make it a non-breaking change in terms of
the DSL, although we will be removing the code that attempts to divine whether an ID autoincrements,
so it might in theory break things, and we should treat it as a breaking change.

You can now add the id field to `attr_columns` even if the ID field autoincrements. Which means
that you can refer to the id field by name as an attribute instead of using `@model_id`, if you
want.

Some minor points that arise from this:

* #to_ot should always include the ID field, whether or not it is named in `attr_columns`.
  Currently we don't do this, although now you can name the ID field in `attr_columns` it becomes
  less of a problem.

* We should not allow manual update of the ID field if it exists as an attribute and auto-increment
  is true.  We don't pass such changes on to the interface.



You can declare a custom list method
------------------------------------

```
class Bar < Pod4::Model

  class Interface < Pod4::PgInterface
    set table :bar
    set_id_field :id, autoincrement: true

    ##
    # Example custom interface method
    #
    def list_paged(drop=0, limit=15)
      execute %Q|select * from bar offset #{drop} rows fetch next #{limit} rows only;|
    end

  end # of Interface

  set_interface   Interface.new($conn)
  set_custom_list :list_paged
end
```

(Syntax is provisional.)

Calling `Bar.list_paged(30,15)` results in `list_paged(30,15)` being run on the interface and the
result converted to Bar objects just as `Bar.list` does.

I'll consider facilitating custom create/read/update/delete methods (`set_custom_action`?) if I can
think of a need for it, but at the end of the day this is just a convenience feature. You can do
all this yourself already if you create your own method in the model. So far I've made about a
dozen custom list methods, but maybe one custom action method (for a Nebulous verb)? 



Model Status :empty
-------------------

This will be renamed to :unknown to reflect that it is also the status of objects created by #list;
:unknown means that validation has not been run yet.

