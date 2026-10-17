# frozen_string_literal: true

module Shares
  module Operations
    class CreateShortLink < Blog::Operation
      include Deps[
        contract: "contracts.short_link_contract", short_code_queries: "repos.short_code_queries",
        queue_title_fetch: "operations.queue_title_fetch", short_link_mutations: "repos.short_link_mutations",
        short_link_queries: "repos.short_link_queries",
      ]

      def call(params)
        fields = step validate(params)

        step(create(fields)).tap { fetch_title(it) }
      end

      private

      def create(fields)
        attempts = fields[:code] ? 1 : Helpers::Code::ATTEMPTS

        Helpers::Code.taken(short_link_mutations) do
          Helpers::Code.retrying(short_link_mutations, attempts) { insert(fields) }
        end
      end

      def fetch_title(link)
        short_link_mutations.after_commit { queue_title_fetch.call(link.id) } unless link.title
      end

      def insert(fields)
        id = short_link_mutations.create(code: fields[:code] || short_code_queries.free_code, **fields.except(:code))
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
