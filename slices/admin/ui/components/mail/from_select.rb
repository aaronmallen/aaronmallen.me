# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class FromSelect < Component
          prop :scope, Blog::Types::String
          prop :senders, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :from, Blog::Types::Integer.optional
          prop :errors, Blog::Types::Hash
          prop :none, Blog::Types::String
          prop :attributes, Blog::Types::Hash, :**

          def view_template
            return span(class: "mail-head-none") { @none } if @senders.empty?

            Select(**FieldError.control_attributes(:from, @errors, @scope), **select_attributes, **@attributes)
          end

          private

          def select_attributes
            options = @senders.to_h { [it.id.to_s, it.address] }

            { name: "mail[from]", options:, selected: @from&.to_s, data: { mail_from: "" } }
          end
        end
      end
    end
  end
end
