# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryNewForm < Component
          prop :scopes, Blog::Types::Array
          prop :values, Blog::Types::Hash
          prop :errors, Blog::Types::Hash
          prop :keep, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

          def view_template
            details(class: "memory-new", open: @errors.any?) do
              Button(summary: true, variant: :pri, icon: "fa-solid fa-plus") { t(".new") }
              Form(action: path(:admin_create_memory_file), class: "memory-new-form card") do
                path_field
                scope_field
                description_field
                Button(type: "submit", variant: :pri) { t(".create") }
                Button(href: path(:admin_memory_files, **@keep), variant: :gh) { t(".cancel") }
              end
            end
          end

          private

          def description_field
            Field(label: t(".description"), name: :description, errors: @errors, error: MemoryFieldError) do |control|
              hint = t(".description_hint")
              Input(**control, name: "memory_file[description]", value: @values[:description], placeholder: hint)
            end
          end

          def path_field
            Field(label: t(".path"), name: :path, errors: @errors, error: MemoryFieldError) do |control|
              Input(**control, name: "memory_file[path]", value: @values[:path], placeholder: t(".path_hint"))
            end
          end

          def scope_field
            Field(label: t(".scope"), name: :scope, errors: @errors, error: MemoryFieldError) do |control|
              MemoryScopeSelect(**control, scopes: @scopes, selected: @values[:scope])
            end
          end
        end
      end
    end
  end
end
