# frozen_string_literal: true

require "securerandom"

module Social
  module Mastodon
    class Form
      attr_reader :content_type

      def initialize(**fields)
        @boundary = SecureRandom.hex
        @content_type = "multipart/form-data; boundary=#{@boundary}"
        @fields = fields.reject { |_, value| value.to_s.empty? }
      end

      def body = @fields.map { |name, value| part(name, *value) }.join + "--#{@boundary}--\r\n"

      private

      def part(name, value, type = nil)
        head = %(--#{@boundary}\r\nContent-Disposition: form-data; name="#{name}")
        head += %(; filename="#{name}.#{type.split('/').last}"\r\nContent-Type: #{type}) if type

        "#{head}\r\n\r\n".b + value.b + "\r\n".b
      end
    end
  end
end
