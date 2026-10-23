# frozen_string_literal: true

module Tags
  module Operations
    class SaveTag < Blog::Operation
      NAME_KEY = "tags_project_id_scope_name_index"
      TAKEN = "taken"

      include Deps[
        contract: "contracts.tag_contract", tag_mutations: "repos.tag_mutations", tag_queries: "repos.tag_queries",
      ]

      def call(params, scope:, id: nil, project_id: nil)
        step find(id, scope, project_id)
        fields = step validate(params)

        step persist(id, scope, project_id, fields)
      end

      private

      def changes(fields) = fields.compact.merge(fields.slice(:description))

      def find(id, scope, project_id)
        return Success(nil) unless id

        found(tag_queries.find_in(scope, id, project_id:) && id)
      end

      def form(params) = { color: params[:color], name: params[:name], **params.slice(:description) }

      def persist(id, scope, project_id, fields)
        constrained(tag_mutations, NAME_KEY => [:name, TAKEN]) do
          Success(transaction { id ? tag_mutations.update(id, **changes(fields)) : store(scope, project_id, fields) })
        end
      end

      def store(scope, project_id, fields)
        color = tag_queries.next_color(scope:, project_id:)

        tag_mutations.create(scope:, project_id:, color:, **fields.compact)
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
