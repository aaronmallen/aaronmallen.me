# frozen_string_literal: true

module Projects
  module Relations
    class ProjectTags < Blog::DB::Relation
      include Blog::DB::Taggings

      schema :project_tags, infer: true do
        associations do
          belongs_to :tag
        end
      end

      def owner_key = :project_id
    end
  end
end
