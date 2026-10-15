# frozen_string_literal: true

require "openssl"

module Services
  class Encryptor
    BASE64 = "m0"
    CIPHER = "aes-256-gcm"
    HEADER_SIZE = 28
    INFO = "blog-encryptor"
    IV_SIZE = 12
    KEY_SIZE = 32

    class Invalid < StandardError
    end

    def initialize(data_key = settings.data_key, previous_data_key = settings.previous_data_key)
      @key, *@previous_keys = [data_key, previous_data_key].compact.map { derive(it) }
    end

    def open(sealed) = open_under([@key, *@previous_keys], sealed)

    def reseal(sealed)
      open_under([@key], sealed)
      nil
    rescue Invalid
      seal(open_under(@previous_keys, sealed))
    end

    def seal(text)
      cipher = cipher(:encrypt)
      iv = cipher.random_iv
      body = cipher.update(text.to_s) + cipher.final
      [iv + cipher.auth_tag + body].pack(BASE64)
    end

    private

    def cipher(mode, key = @key)
      OpenSSL::Cipher.new(CIPHER).public_send(mode).tap { it.key = key }
    end

    def decrypt(raw, key)
      cipher = cipher(:decrypt, key)
      cipher.iv = raw.byteslice(0, IV_SIZE)
      cipher.auth_tag = raw.byteslice(IV_SIZE...HEADER_SIZE)
      (cipher.update(raw.byteslice(HEADER_SIZE..)) + cipher.final).force_encoding(Encoding::UTF_8)
    end

    def derive(data_key) = OpenSSL::KDF.hkdf(data_key, salt: "", info: INFO, length: KEY_SIZE, hash: "SHA256")

    def open_under(keys, sealed)
      raw = sealed.to_s.unpack1(BASE64)
      raise Invalid, "sealed text is too short" if raw.bytesize < HEADER_SIZE

      keys.each do |key|
        return decrypt(raw, key)
      rescue OpenSSL::Cipher::CipherError
        next
      end
      raise Invalid, "sealed text was changed or sealed under another key"
    rescue ArgumentError
      raise Invalid, "sealed text was changed or sealed under another key"
    end

    def settings = Hanami.app.settings
  end
end
