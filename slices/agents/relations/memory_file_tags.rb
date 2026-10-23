# frozen_string_literal: true

module Agents
  module Relations
    class MemoryFileTags < Blog::DB::Relation
      use :taggings

      schema :memory_file_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
