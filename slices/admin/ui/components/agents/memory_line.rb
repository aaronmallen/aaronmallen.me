# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryLine < Component
          prop :file, Blog::Types::Instance(ROM::Struct)
          prop :facts, Blog::Types::Integer
          prop :href, Blog::Types::String.optional
          prop :path, Blog::Types::String.optional, default: nil

          def view_template
            tag(@href ? :a : :span, class: "record-link-title memory-line", href: @href) do
              span(class: "memory-line-head") do
                span(class: "memory-line-path") do
                  span(class: "meta") { "#{@file.scope} " }
                  plain @path || @file.path
                end
                span(class: "meta") { t(".facts", count: @facts) }
              end
              MemoryDescription(file: @file, tag: :span)
            end
          end
        end
      end
    end
  end
end
