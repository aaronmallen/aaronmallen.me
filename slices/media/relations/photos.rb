# frozen_string_literal: true

module Media
  module Relations
    class Photos < Blog::DB::Relation
      COMMENT = Blog::Types::PhotoOwner["task_comment"]
      POST = Blog::Types::PhotoOwner["post"]
      PUBLIC = Blog::Types::ProjectVisibility["public"]
      PUBLISHED = Blog::Types::PostStatus["published"]
      TASK = Blog::Types::PhotoOwner["task"]

      schema :photos, infer: true

      def published
        posts = table(:posts).where(status: PUBLISHED).select(:id)
        tasks = board_tasks
        comments = table(:task_comments).where(task_id: tasks).select(:id)
        owners = Sequel.|({ owner: POST, owner_id: posts }, { owner: TASK, owner_id: tasks },
                          { owner: COMMENT, owner_id: comments })

        where(id: table(:photo_claims).where(owners).select(:photo_id))
      end

      def unclaimed = exclude(id: dataset.db[:photo_claims].select(:photo_id))

      def uploaded_before(at) = where { created_at < at }

      def with_keys(keys) = where(key: keys)

      private

      def board_tasks
        boards = table(:projects).where(visibility: PUBLIC, board_published: true).select(:id)
        table(:tasks).where(project_id: boards).select(:id)
      end

      def table(name) = dataset.db[name]
    end
  end
end
