# frozen_string_literal: true

module Media
  module PhotoType
    ALL_PAGES = "n=-1"
    FIRST_PAGE = ""
    LOSSLESS = {}.freeze
    LOSSY = { Q: 85 }.freeze

    Type = Data.define(:extension, :content_type, :load_options, :save_options)

    GIF = Type.new(extension: "gif", content_type: "image/gif", load_options: ALL_PAGES, save_options: LOSSLESS)
    JPEG = Type.new(extension: "jpg", content_type: "image/jpeg", load_options: FIRST_PAGE, save_options: LOSSY)
    PNG = Type.new(extension: "png", content_type: "image/png", load_options: FIRST_PAGE, save_options: LOSSLESS)
    WEBP = Type.new(extension: "webp", content_type: "image/webp", load_options: ALL_PAGES, save_options: LOSSY)

    BRAND = 4
    FILE_TYPE_BOX = "ftyp"
    HEADER_SIZE = 64
    HEIC_BRANDS = %w[heic heim heis heix hevc hevm hevs hevx].freeze
    HEIF_BRANDS = %w[mif1 msf1].freeze
    KEY = /\A[0-9a-f]{32}\.(?:gif|jpg|png|webp)\z/
    SIGNATURES = {
      "\xFF\xD8\xFF".b => JPEG,
      "\x89PNG\r\n\x1A\n".b => PNG,
      "GIF87a".b => GIF,
      "GIF89a".b => GIF,
    }.freeze
    WEBP_SIGNATURE = /\ARIFF.{4}WEBP/mn

    module_function

    def brands(header)
      box_size = header.unpack1("N").to_i.clamp(0, header.bytesize)
      major = header.byteslice(8, BRAND)
      compatible = header.byteslice(16, [box_size - 16, 0].max).to_s.scan(/.{4}/mn)

      [major, compatible]
    end

    def detect(io)
      header = io.read(HEADER_SIZE).to_s.b
      io.rewind

      signed(header) || (WEBP if header.match?(WEBP_SIGNATURE)) || (JPEG if heic?(header))
    end

    def heic?(header)
      return false unless header.byteslice(4, BRAND) == FILE_TYPE_BOX

      major, compatible = brands(header)
      HEIC_BRANDS.include?(major) || (HEIF_BRANDS.include?(major) && compatible.intersect?(HEIC_BRANDS))
    end

    def signed(header) = SIGNATURES.find { |signature, _| header.start_with?(signature) }&.last
  end
end
