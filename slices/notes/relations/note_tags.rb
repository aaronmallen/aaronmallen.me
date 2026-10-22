# frozen_string_literal: true

module Notes
  module Relations
    class NoteTags < Blog::DB::Relation
      use :taggings

      schema :note_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
