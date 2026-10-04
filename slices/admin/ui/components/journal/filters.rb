# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class Filters < Component
          prop :search, Blog::Types::String
          prop :entry_date, Blog::Types::String
          prop :today, Blog::Types::Date
          prop :streak, Blog::Types::Hash
          prop :errors, Blog::Types::Hash
          prop :saved_views, Blog::Types::Hash

          def view_template
            div(class: "journal-rail") do
              Card do
                div(class: "form-stack") do
                  SavedViews(**@saved_views)
                  search_field
                  date_field
                  streak
                end
              end
            end
          end

          private

          def date_field
            Field(label: t(".entry_date"), id: FieldError.id_for(:entry_date)) do
              Input(
                **FieldError.control_attributes(:entry_date, @errors),
                type: "date",
                name: "entry[entry_date]",
                value: @entry_date,
                max: @today.iso8601,
                form: NewEntry::FORM_ID,
                data: { journal_date: "" },
              )
              FieldError(field: :entry_date, errors: @errors)
            end
          end

          def search_field
            form(action: path(:admin_journal), method: "get", role: "search") do
              Field(label: t(".search"), id: "journal-search") do
                Input(type: "search", id: "journal-search", name: "q", value: @search,
                      placeholder: t(".search_placeholder"))
              end
            end
          end

          def streak
            Field(label: t(".streak")) do
              p(class: "journal-streak") { t(".streak_days", written: @streak[:written], days: @streak[:days]) }
            end
          end
        end
      end
    end
  end
end
