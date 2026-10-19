# frozen_string_literal: true

module Shares
  module Operations
    class CreateShortLink < Blog::Operation
      include Deps[
        contract: "contracts.short_link_contract",
        queue_title_fetch: "operations.queue_title_fetch", short_link_mutations: "repos.short_link_mutations",
        short_link_queries: "repos.short_link_queries",
      ]

      def call(params)
        fields = step validate(params)

        step(create(fields)).tap { fetch_title(it) }
      end

      private

      def create(fields)
        constrained(short_link_mutations, Helpers::Code::CONSTRAINTS) do
          Helpers::Code.retrying(short_link_mutations) { insert(fields) }
        end
      end

      def fetch_title(link)
        short_link_mutations.after_commit { queue_title_fetch.call(link.id) } unless link.title
      end

      def insert(fields)
        id = short_link_mutations.create(**fields)
        Success(short_link_queries.find(id))
      end

      def validate(params)
        code = Blog::Types::OptionalText[params[:code]]
        form = { destination: params[:destination], title: params[:title] }

        validated(contract.call(code ? form.merge(code:) : form))
      end
    end
  end
end
