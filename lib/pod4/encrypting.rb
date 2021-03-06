require "openssl"
require "base64"
require "pod4/errors"
require "pod4/metaxing"


module Pod4


  ##
  # A mixin to give you basic encryption, transparently.
  #
  # Example
  # -------
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
  # So, this adds `set_key`, `set_iv_column`, and `encrypted_columns` to the model DSL. Only
  # `set_iv_column` is optional, and it is **highly** recommended.
  #
  # set_key
  # -------
  #
  # Can be any string you like, but should ideally be long and random. If it's not long enough you
  # will get an exception.  The key is used for all encryption on the model.
  #
  # You probably have a single key for the entire database and pass it to your application via an
  # environment variable. But we don't care about that.
  #
  # If you set the key to nil, then the model should work exactly as if the encryption mixin was
  # not present.
  #
  # set_iv_column
  # -------------
  #
  # The name of a text column on the table which holds the initialisation vector, or nonce, for the
  # record.  IVs don't have to be secret, but they should be different for each record; we take
  # care of creating them for you.
  #
  # If you don't provide an IV column, then we fall back to insecure ECB mode for the encryption.
  # Don't make us do that.
  #
  # encrypted_columns
  # -----------------
  #
  # The list of columns to encrypt.  In addition, it acts just the same as attr_columns, so you can
  # name the column there too, or not.  Up to you.
  #
  # Changes to Behaviour of Model
  # -----------------------------
  #
  # `map_to_interface`: data going from the model to the interface has the relevant columns
  # encrypted.  If the IV column is nil, we set it to a good IV.
  #
  # `map_to_model`: data going from the interface to the model has the relevant columns decrypted.
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
  # Additional Methods
  # ------------------
  #
  # You will almost certainly never need to use these.
  #
  # * `encryption_iv` returns the value of the IV column of the record, whatever it is.
  #
  # * `encrypt` and `decrypt` allow you to transform arbitrary text in a manner compatible with the
  #   model -- for example, if you removed a column from `encrypted_columns`, you could do a
  #   one-time decrypt of your data.
  #
  # Notes
  # -----
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
        return super if self.class.encryption_key.nil?

        hash   = super.to_h
        cipher = get_cipher(:encrypt)

        # Each time we write, we set a new IV. We must also set it on the hash to go to the
        # interface, where it must be base64 encoded, just like the encrypted columns.
        if use_iv? 
          set_encryption_iv( cipher.random_iv )
          hash[self.class.encryption_iv_column] = Base64.strict_encode64(encryption_iv)
        end

        self.class.encryption_columns.each do |col|
          hash[col] = crypt(cipher, :encrypt, encryption_iv, hash[col])
        end

        Octothorpe.new(hash)
      end

      ##
      # When mapping to the model, decrypt the encrypted columns from the interface
      #
      def map_to_model(ot)
        return super(ot) if self.class.encryption_key.nil?

        hash   = ot.to_h
        cipher = get_cipher(:decrypt)

        # The IV column is not in columns, so we need to de-base-64 it and set it on the model here
        if use_iv? && (iv64 = hash[self.class.encryption_iv_column])
          set_encryption_iv Base64.strict_decode64(iv64)
        end

        self.class.encryption_columns.each do |col|
          hash[col] = crypt(cipher, :decrypt, encryption_iv, hash[col])
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

      ##
      # Public facing manual encryption, compatible with the current model
      #
      def encrypt(string)
        cipher = get_cipher(:encrypt)
        iv     = use_iv? ? encryption_iv : nil
        crypt(cipher, :encrypt, iv, string)
      end

      ##
      # Public facing manual decryption, compatible with the current model
      #
      def decrypt(string)
        cipher = get_cipher(:decrypt)
        iv     = use_iv? ? encryption_iv : nil
        crypt(cipher, :decrypt, iv, string)
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

      rescue OpenSSL::Cipher::CipherError
        raise Pod4::Pod4Error, $!
      end

      ##
      # Encrypt / decrypt
      #
      def crypt(cipher, direction, iv, string)
        return string if use_iv? and iv.nil?
        return string if string.nil? 
        cipher.key = self.class.encryption_key
        cipher.iv = iv if use_iv?

        case direction
          when :encrypt
            answer = string.to_s.empty? ? "" : cipher.update(string.to_s)
            answer << cipher.final
            Base64.strict_encode64(answer)

          when :decrypt
            answer = Base64.strict_decode64(string.to_s)
            cipher.update(answer) + cipher.final
        end

      rescue OpenSSL::Cipher::CipherError, ArgumentError
        raise Pod4::Pod4Error, $!
      end

    end # of InstanceMethods


  end # of Encrypting

end

