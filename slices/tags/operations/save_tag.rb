# frozen_string_literal: true

module Tags
  module Operations
    class SaveTag < Blog::Operation
      NAME_KEY = "tags_scope_name_key"
      TAKEN = "taken"

      include Deps[
        contract: "contracts.tag_contract", tag_mutations: "repos.tag_mutations", tag_queries: "repos.tag_queries",
      ]

      def call(params, scope:, id: nil)
        step find(id, scope)
        fields = step validate(params)

        step persist(id, scope, fields)
      end

      private

      def changes(fields) = fields.compact.merge(fields.slice(:description))

      def find(id, scope)
        return Success(nil) unless id

        found(tag_queries.find_in(scope, id) && id)
      end

      def form(params) = { color: params[:color], name: params[:name], **params.slice(:description) }

      def persist(id, scope, fields)
        constrained(tag_mutations, NAME_KEY => [:name, TAKEN]) do
          Success(transaction { id ? tag_mutations.update(id, **changes(fields)) : store(scope, fields) })
        end
      end

      def store(scope, fields) = tag_mutations.create(scope:, color: tag_queries.next_color(scope:), **fields.compact)

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
