module Pod4


  ##
  # A little mixin for metaprogramming
  #
  module Metaxing

    ##
    # Return the metaclass (eigenclass) of self.
    #
    def metaclass
      class << self; self; end
    end


    ##
    # Define (or re-define) a class method.
    #
    # Example:
    #     
    #     class Foo
    #       extend Metaxing
    #
    #       class << self
    #         def set_bar(x); define_class_method(:bar) {x}; end
    #       end
    #     end
    #
    #     class MyFoo < Foo; end
    #
    #     Foo.set_bar(23)
    #     puts Foo.bar   # -> 23
    #     puts MyFoo.bar # -> 23
    #
    #     MyFoo.set_bar(42) 
    #     puts Foo.bar   # -> 23
    #     puts MyFoo.bar # -> 42
    # 
    # This example gives us something different from a class attribute @@bar -- the value of which
    # would be shared between Foo and MyFoo.  And different again from an attribute @bar on class
    # Foo, which wouldn't turn up in MyFoo at all. This is a value that has inheritance.
    #
    # And this example shows pretty much the only metaprogramming trick you will find me pulling.
    # It's enough to do a hell of a lot.
    #
    # Note that you need to be very careful what parameters you pass in order to preserve this
    # inheritance: if you pass a reference to something on Foo, you will be sharing it with MyFoo,
    # not just inheriting it. Best to use local variables or dups.
    #
    # ...Well, actually, you aren't getting a method on the class -- these are defined in the
    # class' immediate ancestor, eg, Object. You're getting a method on the eigenclass, which Ruby
    # inserts between the class' ancestor and the class. For all of me I can't see a practical
    # difference when it comes to defining class methods.
    #
    def define_class_method(method, *args, &blk)
      metaclass.send(:define_method, method, *args, &blk)
    end

  end


end
