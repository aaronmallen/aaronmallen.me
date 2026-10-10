# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SuggestionEdit < Component
        prop :original, Blog::Types::String
        prop :replacement, Blog::Types::String
        prop :reason, Blog::Types::String
        prop :stale, Blog::Types::Bool
        prop :label, Blog::Types::String.optional, default: nil

        def view_template
          div(class: "sg-edit") do
            p(class: "sg-part") { @label } if @label
            diff
            p(class: "sg-reason") { @reason }
            div(class: "sg-actions") do
              Pill(color: :sand) { t(".stale") } if @stale
              yield
            end
          end
        end

        private

        def diff
          p(class: "sg-diff") do
            del(class: "sg-before") { @original }
            ins(class: "sg-after") { @replacement }
          end
        end
      end
    end
  end
end
