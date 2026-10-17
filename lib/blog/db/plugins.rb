# frozen_string_literal: true

require "rom/core"

module Blog
  module DB
    module Plugins
      ROM.plugins do
        adapter :sql do
          register :crediting, Crediting, type: :relation
          register :full_text, FullText, type: :relation
          register :taggings, Taggings, type: :relation
          register :tags, Tags, type: :relation
        end
      end
    end
  end
end
