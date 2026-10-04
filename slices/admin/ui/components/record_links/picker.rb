# frozen_string_literal: true

module Admin
  module UI
    module Components
      module RecordLinks
        class Picker < Component
          prop :scope, Blog::Types::String
          prop :link_path, Blog::Types::String
          prop :find_path, Blog::Types::String
          prop :fields, Blog::Types::Hash
          prop :query, Blog::Types::String, default: -> { Blog::Constants::EMPTY_STRING }
          prop :found, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
          prop :errors, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template
            div(class: "record-picker") do
              Field(label: t(".label"), id: query_id) do
                find_form
                FieldError(field: :other_kind, errors: @errors, scope: @scope)
                FieldError(field: :other_id, errors: @errors, scope: @scope)
                results unless @query.empty?
              end
            end
          end

          private

          def find_form
            Form(method: "get", action: @find_path, class: "record-picker-find") do
              hidden_fields(@fields)
              Input(
                **FieldError.control_attributes(:other_id, @errors, @scope),
                type: "search", name: "record_q", value: @query, placeholder: t(".placeholder"),
              )
              Button(type: "submit", small: true, data: { task_find: @find_path }) { t(".find") }
            end
          end

          def hidden_fields(fields)
            fields.compact.each { |name, value| input(type: "hidden", name: name.to_s, value:) }
          end

          def pick(kind, link)
            Form(action: @link_path, class: "record-picker-pick") do
              hidden_fields({ **@fields, record_q: @query, "record[other_kind]": kind, "record[other_id]": link.id })
              button(type: "submit", class: "record-picker-target") do
                i(class: "fa-solid fa-plus", aria: { hidden: "true" })
                span(class: "record-link-title") { link.title }
                time(class: "record-link-day", datetime: link.day.iso8601) { l(link.day, format: :medium) }
              end
            end
          end

          def query_id = FieldError.id_for(:other_id, @scope)

          def results
            return Hint { t(".no_match") } if @found.empty?

            div(class: "record-picker-results") do
              @found.each do |kind, rows|
                div(class: "record-link-group") do
                  h3(class: "record-link-kind") { t(Section.kind_name_key(kind)) }
                  ul(class: "record-link-list") { rows.each { |row| li { pick(kind, row) } } }
                end
              end
            end
          end
        end
      end
    end
  end
end
