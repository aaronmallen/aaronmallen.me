# frozen_string_literal: true

module Contact
  module Operations
    class LabelMessage < Blog::Operation
      include Deps[
        contract: "contracts.label_contract",
        message_queries: "repos.message_queries",
        message_tag_mutations: "repos.message_tag_mutations",
      ]

      def call(id, tags)
        names = step(validated(contract.call(tags:)))[:tags]
        step found(message_queries.exist?(id))

        transaction { message_tag_mutations.replace(id, names) }
        Success(names)
      end
    end
  end
end
