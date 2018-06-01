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
    CIPHER_IV    = "AES-128-CBC"
    CIPHER_NO_IV = "AES-128-ECB"

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
        attr_columns column unless columns.include? column
      end

      def encrypted_columns(*ecolumns)
        ec = encryption_columns.dup + ecolumns
        define_class_method(:encryption_columns) {ec}
        attr_columns( *(ec - columns) )
      end

      def encryption_key;         nil;  end
      def encryption_iv_column;   nil;  end
      def encryption_columns;     [];   end

    end # of ClassMethods


    module InstanceMethods

      ##
      # When mapping to the interface, encrypt the encryptable columns from the model
      #
      def map_to_interface
        hash   = super.to_h
        cipher = get_cipher(:encrypt)

        # If the IV is not set we need to set it both in the model object AND the hash, since we've
        # already obtained the hash from the model object.
        if use_iv? && encryption_iv.nil?
          set_encryption_iv( cipher.random_iv )
          hash[self.class.encryption_iv_column] = encryption_iv
        end

        self.class.encryption_columns.each do |col|
          hash[col] = crypt(cipher, encryption_iv, hash[col])
        end

        Octothorpe.new(hash)
      end

      ##
      # When mapping to the model, decrypt the encrypted columns from the interface
      #
      def map_to_model(ot)
        hash   = ot.to_h
        cipher = get_cipher(:decrypt)
        iv     = hash[self.class.encryption_iv_column] # not yet set on the model

        self.class.encryption_columns.each do |col|
          hash[col] = crypt(cipher, iv, hash[col])
        end

        super Octothorpe.new(hash)
      end

      ## 
      # The value of the IV field (whatever it is) _as currently stored on the model_
      #
      def encryption_iv
        return nil unless use_iv?
        instance_variable_get( "@#{self.class.encryption_iv_column}".to_sym )
      end

      private

      ##
      # Set the iv column on the model, whatever it is
      #
      def set_encryption_iv(iv)
        return unless use_iv?
        instance_variable_set( "@#{self.class.encryption_iv_column}".to_sym, iv )
      end

      ##
      # If we have declared an IV column, we can use IV in encryption
      #
      def use_iv?
        !self.class.encryption_iv_column.nil?
      end

      ##
      # Return the correct OpenSSL Cipher object
      #
      def get_cipher(direction)
        cipher = OpenSSL::Cipher.new(use_iv? ? CIPHER_IV : CIPHER_NO_IV)
        case direction
          when :encrypt then cipher.encrypt
          when :decrypt then cipher.decrypt
        end
        cipher
      end

      ##
      # Encrypt / decrypt
      #
      def crypt(cipher, iv, string)
        return string if use_iv? and iv.nil?
        cipher.key = self.class.encryption_key
        cipher.iv = iv if use_iv?
        cipher.update(string) + cipher.final
      end

    end # of InstanceMethods


  end # of Encrypting

end

