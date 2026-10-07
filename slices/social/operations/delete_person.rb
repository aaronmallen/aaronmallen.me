# frozen_string_literal: true

module Social
  module Operations
    class DeletePerson < Operation
      include Deps[person_mutations: "repos.person_mutations", person_queries: "repos.person_queries"]

      def call(id)
        person = step find(id)

        person_mutations.delete(person.id)
      end

      private

      def find(id)
        found(person_queries.by_id(id))
      end
    end
  end
end
