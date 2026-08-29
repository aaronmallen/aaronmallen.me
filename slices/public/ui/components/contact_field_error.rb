# frozen_string_literal: true

module Public
  module UI
    module Components
      class ContactFieldError < Blog::UI::FieldError
        SCOPE = "cf"
        SLUGS = { body: "message", reply_to: "email" }.freeze
        MESSAGES = {
          body: { "blank" => ".body.blank", "control" => ".body.control", "long" => ".body.long" },
          reply_to: {
            "blank" => ".reply_to.blank",
            "control" => ".reply_to.control",
            "format" => ".reply_to.format",
            "long" => ".reply_to.long",
          },
          subject: { "blank" => ".subject.blank", "control" => ".subject.control", "long" => ".subject.long" },
        }.freeze
        BROWSER_CODES = %w[blank format].freeze

        def self.field_slug(field) = SLUGS.fetch(field) { super.tr("_", "-") }

        def view_template
          code = Array(@errors[@field]).first

          p(**error_attributes(code)) { t(message_key(code)) if code }
        end

        private

        def browser_messages
          MESSAGES.fetch(@field, Dry::Core::Constants::EMPTY_HASH)
                  .slice(*BROWSER_CODES)
                  .to_h { |code, key| [code.to_sym, t(key)] }
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
