# frozen_string_literal: true

module Public
  module UI
    module Components
      class ContactFieldError < Blog::UI::FieldError
        SCOPE = "cf"
        SLUGS = { body: "message", reply_to: "email" }.freeze
        BROWSER_CODES = %w[blank format].freeze

        def self.field_slug(field) = SLUGS.fetch(field) { super.tr("_", "-") }

        def view_template
          code = Array(@errors[@field]).first

          p(**error_attributes(code)) { message(code) if code }
        end

        private

        def browser_messages
          BROWSER_CODES.filter_map do |code|
            text = t(convention_key(code), default: nil)
            [code.to_sym, text] if text
          end.to_h
        end

        def error_attributes(code)
          {
            class: "f-e",
            data: { for: self.class.id_for(@field, @scope), **browser_messages },
            hidden: code.nil?,
            id: error_id,
          }
        end
      end
    end
  end
end
