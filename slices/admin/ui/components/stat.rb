# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Stat < Component
        prop :key, Blog::Types::String
        prop :value, Blog::Types::String | Blog::Types::Integer
        prop :change, Blog::Types::String.optional

        def view_template
          div(class: "stat") do
            div(class: "stat-key") { @key }
            div(class: "stat-value") { @value.to_s }
            div(class: "stat-change") { @change } if @change
          end
        end
      end
    end
  end
end
