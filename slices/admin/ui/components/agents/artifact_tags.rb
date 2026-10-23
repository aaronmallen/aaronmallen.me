# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactTags < Component
          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :keys, Blog::Types::Hash

          def view_template = @tags.each { Tag(tag: it, project_key: @keys[it.project_id]) }
        end
      end
    end
  end
end
