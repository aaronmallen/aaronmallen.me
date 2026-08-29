# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Projects
        class Repository < Component
          prop :values, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::String)
          prop :errors, Blog::Types::Hash
          prop :release, Blog::Types::String.optional
          prop :stars, Blog::Types::Integer

          def view_template
            Card(label: t(".heading")) do
              div(class: "form-stack") do
                repo_field
                url_field
                from_github
                started_on_field
                Hint { t(".sync_note") }
              end
            end
          end

          private

          def field(name, label_key, &)
            Field(label: t(label_key), id: FieldError.id_for(name)) do
              yield
              FieldError(field: name, errors: @errors)
            end
          end

          def from_github
            read_only(t(".stars"), Blog::Figures.count(@stars))
            read_only(t(".release"), @release.to_s.empty? ? t(".none") : @release)
          end

          def read_only(label_text, value)
            Field(label: label_text) do
              p(class: "field-value") { value }
            end
          end

          def repo_field
            field(:repo, ".repo") do
              Input(
                **FieldError.control_attributes(:repo, @errors),
                name: "project[repo]",
                value: @values[:repo],
                placeholder: t(".repo_placeholder"),
                data: { editor_repo_input: "" },
              )
            end
          end

          def started_on_field
            field(:started_on, ".started_on") do
              Input(
                **FieldError.control_attributes(:started_on, @errors),
                name: "project[started_on]",
                value: @values[:started_on],
                placeholder: t(".started_on_placeholder"),
              )
            end
          end

          def url_field
            field(:url, ".url") do
              Input(
                **FieldError.control_attributes(:url, @errors),
                type: "url",
                name: "project[url]",
                value: @values[:url],
                placeholder: t(".url_placeholder"),
              )
              Hint { t(".url_note") }
            end
          end
        end
      end
    end
  end
end
