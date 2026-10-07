# frozen_string_literal: true

module Posts
  module Operations
    class TagPost < Operation
      include Deps[post_repo: "repos.post_repo"]

      def call(id, name)
        transaction do
          step find(id)
          post_repo.add_tag(id, name)
          post_repo.by_id(id)
        end
      end

      private

      def find(id) = found(post_repo.by_id_for_update(id) && id)
    end
  end
end
