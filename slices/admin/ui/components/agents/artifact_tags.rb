# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactTags < Component
          FALLBACK = :violet

          prop :tags, Blog::Types::Array.of(Blog::Types::String)
          prop :colors, Blog::Types::Hash

          def view_template
            @tags.each do |tag|
              span(class: ["tag", (Blog::UI::Components::Pill.for_tag_color(@colors[tag]) || FALLBACK).to_s]) do
                "#{Tag::PREFIX}#{tag}"
              end
            end
          end
        end
      end
    end
  end
end
