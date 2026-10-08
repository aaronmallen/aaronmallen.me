# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Comments < Component
          ROUTES = {
            create: :admin_create_decision_comment, update: :admin_update_decision_comment,
            delete: :admin_delete_decision_comment,
          }.freeze

          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :form, Blog::Types::Hash

          def view_template
            Card(title: t(".title")) do
              CommentThread(
                record_id: @decision.id, entries: @entries.select(&:comment?), routes: ROUTES, scope: "decision",
                form: commenting, error: FieldError,
              )
            end
          end

          private

          def commenting
            return Blog::Constants::EMPTY_HASH unless @form[:name] == :comment

            { id: @form[:id], body: Blog::Types::Text[@form[:params][:body]], errors: @form[:errors] }
          end
        end
      end
    end
  end
end
