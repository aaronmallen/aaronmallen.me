# frozen_string_literal: true

module Admin
  module UI
    module Components
      class BulkBar < Component
        FIELD = "ids[]"

        prop :id, Blog::Types::String
        prop :action, Blog::Types::String
        prop :label, Blog::Types::String
        prop :fields, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

        def view_template(&)
          Form(id: @id, action: @action, class: "bulk-bar", aria: { label: @label }, data: { bulk: FIELD }) do
            @fields.each { |name, value| input(type: "hidden", name:, value:) }
            all
            span(class: "bulk-count", aria: { live: "polite" }, data: { bulk_count: t(".ticked") })
            div(class: "bulk-acts", data: { bulk_acts: true }, &)
          end
        end

        private

        def all
          label(class: "choice", hidden: true, data: { bulk_all: true }) do
            input(type: "checkbox", class: "check")
            span { t(".all") }
          end
        end
      end
    end
  end
end
