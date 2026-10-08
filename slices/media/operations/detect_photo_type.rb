# frozen_string_literal: true

module Media
  module Operations
    class DetectPhotoType
      BRAND = 4
      FILE_TYPE_BOX = "ftyp"
      HEADER_SIZE = 64
      HEIC_BRANDS = %w[heic heim heis heix hevc hevm hevs hevx].freeze
      HEIF_BRANDS = %w[mif1 msf1].freeze
      JPEG = Blog::Types::PhotoType["jpg"]
      SIGNATURES = {
        "\xFF\xD8\xFF".b => JPEG,
        "\x89PNG\r\n\x1A\n".b => Blog::Types::PhotoType["png"],
        "GIF87a".b => Blog::Types::PhotoType["gif"],
        "GIF89a".b => Blog::Types::PhotoType["gif"],
      }.freeze
      WEBP = Blog::Types::PhotoType["webp"]
      WEBP_SIGNATURE = /\ARIFF.{4}WEBP/mn

      def call(io)
        header = io.read(HEADER_SIZE).to_s.b
        io.rewind

        signed(header) || (WEBP if header.match?(WEBP_SIGNATURE)) || (JPEG if heic?(header))
      end

      private

      def brands(header)
        box_size = header.unpack1("N").to_i.clamp(0, header.bytesize)
        major = header.byteslice(8, BRAND)
        compatible = header.byteslice(16, [box_size - 16, 0].max).to_s.scan(/.{4}/mn)

        [major, compatible]
      end

      def heic?(header)
        return false unless header.byteslice(4, BRAND) == FILE_TYPE_BOX

        major, compatible = brands(header)
        HEIC_BRANDS.include?(major) || (HEIF_BRANDS.include?(major) && compatible.intersect?(HEIC_BRANDS))
      end

      def signed(header) = SIGNATURES.find { |signature, _| header.start_with?(signature) }&.last
    end
  end
end
