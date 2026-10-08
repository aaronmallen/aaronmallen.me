# frozen_string_literal: true

module Projects
  module Relations
    class ProjectTags < Blog::DB::Relation
      use :taggings, owner_key: :project_id

      schema :project_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end
    end
  end
end
