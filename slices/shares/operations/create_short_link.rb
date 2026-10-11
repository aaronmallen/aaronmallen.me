# frozen_string_literal: true

module Shares
  module Operations
    class CreateShortLink < Blog::Operation
      include Deps[
        contract: "contracts.short_link_contract", short_link_mutations: "repos.short_link_mutations",
        short_link_queries: "repos.short_link_queries",
      ]

      def call(params)
        fields = step validate(params)

        step create(fields)
      end

      private

      def create(fields, attempts = Code::ATTEMPTS)
        id = short_link_mutations.create(code: fields[:code] || Code.random, **fields.except(:code))
        Success(short_link_queries.find(id))
      rescue ROM::SQL::UniqueConstraintError => e
        raise unless short_link_mutations.violated_constraint(e) == Code::KEY
        return Failure([:invalid, { code: [Code::TAKEN] }]) if fields[:code] || attempts == 1

        create(fields, attempts - 1)
      end

      def validate(params)
        code = Blog::Types::OptionalText[params[:code]]
        form = { destination: params[:destination], title: params[:title] }

        validated(contract.call(code ? form.merge(code:) : form))
      end
    end
  end
end
