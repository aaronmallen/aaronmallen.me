# frozen_string_literal: true

module Blog
  module UI
    class FieldError < Component
      CODES = "ui.field_error."
      INVALID = "ui.field_error.invalid"
      LIMITS = Blog::Constants::EMPTY_HASH
      OVERRIDES = Blog::Constants::EMPTY_HASH
      UNSHOWN = Blog::Constants::EMPTY_ARRAY
      URL = { "format" => "ui.field_error.url.format" }.freeze

      prop :field, Blog::Types::Symbol
      prop :errors, Blog::Types::Hash
      prop :scope, Blog::Types::String, default: -> { self.class::SCOPE }

      def self.control_attributes(field, errors, scope = self::SCOPE)
        id = id_for(field, scope)
        return { id: } unless errors[field]

        { id:, aria: { invalid: "true", describedby: "#{id}-error" } }
      end

      def self.field_slug(field) = field.to_s

      def self.id_for(field, scope = self::SCOPE) = "#{scope}-#{field_slug(field)}"

      def view_template
        codes = @errors[@field]
        return unless codes

        p(**error_attributes) { message(Array(codes).first) }
      end

      private

      def convention_key(code) = ".#{@field}.#{code}"

      def error_attributes = { class: "field-error", id: error_id }

      def error_id = "#{self.class.id_for(@field, @scope)}-error"

      def message(code)
        keys = [convention_key(code), self.class::OVERRIDES.dig(@field, code), *shared_keys(code)].compact
        limits = self.class::LIMITS.fetch(@field, Blog::Constants::EMPTY_HASH)
        keys.lazy.filter_map { t(it, default: nil, **limits) }.first || t(INVALID)
      end

      def shared_keys(code) = ["#{CODES}#{@field}.#{code}", "#{CODES}#{code}"]
    end
  end
end
