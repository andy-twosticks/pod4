require "openssl"
require "pod4/errors"
require "pod4/metaxing"


module Pod4


  ##
  # A mixin to give you basic encryption, transparently.
  #
  #     class Foo < Pod4::Model
  #       include Pod4::Encrypting
  #
  #       set_key           $encryption_key
  #       set_iv_column     :nonce
  #       encrypted_columns :one, :two, :three
  #
  #       ...
  #     end
  #
  # The given columns will be encrypted in map_to_interface and decrypted in map_to_model.
  #
  # New DSL methods:
  #
  # * set_key: can be any string you like, but it should ideally be long and random.
  #
  # * set_iv_column:  should be the name of a text column in the table. (Actually optional, but
  #   leaving it out is a dreadful idea, because without it we fall back to insecure ECB mode.
  #   Don't make us do that.)
  #
  # * encrypted_columns: the list of columns to encrypt. Acts the same as attr_columns, so you
  #   can name the column there too, or not.  Up to you.
  #
  # Assumptions / limitations:
  #
  # * One key for all the data in the model.
  #
  # * a column on the table holding an initiation vector (IV, nonce) for each record. See above.
  #
  # * we only store encrypted data in text columns, and we can't guarantee that the encrypted data
  #   will be the same length as when unencrypted.
  #
  # Notes:
  #
  # Encryption is provided by OpenSSL::Cipher. For more information, you should read the official
  # Ruby docs for this; they are really helpful.
  #
  module Encrypting
    CIPHER_CBC = "AES-128-CBC"
    CIPHER_ECB = "AES-128-ECB"

    ##
    # A little bit of magic, for which I apologise. 
    #
    # When you include this module it actually adds the methods in ClassMethods to the class as if
    # you had called `extend Encrypting:ClassMethds` *AND* adds the methods in InstanceMethods as
    # if you had written `prepend Encrypting::InstanceMethods`.  
    #
    # In my defence: I didn't want to have to make you remember to do that...
    #
    def self.included(base)
      base.extend  ClassMethods
      base.send(:prepend, InstanceMethods)
    end


    module ClassMethods
      include Metaxing


      def set_key(key)
        define_class_method(:encryption_key) {key}
      end

      def set_iv_column(column)
        define_class_method(:encryption_iv_column) {column}
        attr_columns column
      end

      def encrypted_columns(*ecolumns)
        ec = encryption_columns.dup + ecolumns
        define_class_method(:encryption_columns) {ec}
        attr_columns *(ec - columns)
      end

      def encryption_key;         nil;  end
      def encryption_iv_column;   nil;  end
      def encryption_columns;     [];   end

    end # of ClassMethods


    module InstanceMethods

      def map_to_model(ot)
        hash = ot.to_h

=begin
        self.class.encryption_columns.each do |col|
          crypt(:encode, 
=end

        super Octothorpe.new(hash)
      end

      def map_to_interface
        ot = super
      end

      private

      def crypt(direction, iv, string)
        cipher = OpenSSL::Cipher.new(eiv ? CIPHER_CBC : CIPHER_ECB)
        case direction
          when :encode then cipher.encode
          when :decode then cipher.decode
        end
        cipher.key = self.class.encryption_key
        cipher.iv = iv if iv
        cipher.update(string) + cipher.final
      end


    end # of InstanceMethods


  end # of Encrypting

end

