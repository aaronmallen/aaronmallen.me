# frozen_string_literal: true

module Tags
  module Operations
    class SaveTag < Blog::Operation
      TAKEN = "taken"

      include Deps[contract: "contracts.tag_contract", tag_repo: "repos.tag_repo"]

      def call(params, id: nil)
        step find(id)
        fields = step validate(params)

        step persist(id, fields)
      end

      private

      def find(id)
        return Success(nil) unless id

        tag_repo.by_id(id) ? Success(id) : Failure(:not_found)
      end

      def form(params) = { color: params[:color], name: params[:name] }

      def persist(id, fields)
        Success(transaction { id ? tag_repo.update(id, **fields.compact) : store(fields) })
      rescue ROM::SQL::UniqueConstraintError
        Failure([:invalid, { name: [TAKEN] }])
      end

      def store(fields) = tag_repo.create(color: tag_repo.next_color, **fields.compact)

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
