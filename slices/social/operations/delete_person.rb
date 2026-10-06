# frozen_string_literal: true

module Social
  module Operations
    class DeletePerson < Blog::Operation
      include Deps[person_repo: "repos.person_repo"]

      def call(id)
        person = step find(id)

        person_repo.delete(person.id)
      end

      private

      def find(id)
        found(person_repo.by_id(id))
      end
    end
  end
end
