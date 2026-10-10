# frozen_string_literal: true

module Blog
  module UI
    class FieldError < Component
      INVALID = "ui.field_error.invalid"
      OVERRIDES = Blog::Constants::EMPTY_HASH

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

      def message(code) = t(convention_key(code), default: nil) || t(override_key(code))

      def override_key(code) = self.class::OVERRIDES.dig(@field, code) || INVALID
    end
  end
end
