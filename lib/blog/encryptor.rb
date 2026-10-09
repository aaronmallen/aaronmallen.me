# frozen_string_literal: true

require "openssl"

module Blog
  class Encryptor
    BASE64 = "m0"
    CIPHER = "aes-256-gcm"
    HEADER_SIZE = 28
    INFO = "blog-encryptor"
    IV_SIZE = 12
    KEY_SIZE = 32

    class Invalid < StandardError
    end

    def initialize(data_key = Hanami.app.settings.data_key)
      @key = OpenSSL::KDF.hkdf(data_key, salt: "", info: INFO, length: KEY_SIZE, hash: "SHA256")
    end

    def open(sealed)
      raw = sealed.to_s.unpack1(BASE64)
      raise Invalid, "sealed text is too short" if raw.bytesize < HEADER_SIZE

      cipher = cipher(:decrypt)
      cipher.iv = raw.byteslice(0, IV_SIZE)
      cipher.auth_tag = raw.byteslice(IV_SIZE...HEADER_SIZE)
      (cipher.update(raw.byteslice(HEADER_SIZE..)) + cipher.final).force_encoding(Encoding::UTF_8)
    rescue ArgumentError, OpenSSL::Cipher::CipherError
      raise Invalid, "sealed text was changed or sealed under another key"
    end

    def seal(text)
      cipher = cipher(:encrypt)
      iv = cipher.random_iv
      body = cipher.update(text.to_s) + cipher.final
      [iv + cipher.auth_tag + body].pack(BASE64)
    end

    private

    def cipher(mode)
      OpenSSL::Cipher.new(CIPHER).public_send(mode).tap { it.key = @key }
    end
  end
end
