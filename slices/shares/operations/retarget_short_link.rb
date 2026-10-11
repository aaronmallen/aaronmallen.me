# frozen_string_literal: true

module Shares
  module Operations
    class RetargetShortLink < Blog::Operation
      include Deps[
        contract: "contracts.short_link_contract", short_link_mutations: "repos.short_link_mutations",
        short_link_queries: "repos.short_link_queries",
      ]

      def call(id, params)
        link = step found(short_link_queries.find(id))
        fields = step validated(contract.call(destination: params[:destination]))

        fields[:destination] == link.destination ? link : retarget(link, fields[:destination])
      end

      private

      def retarget(link, destination)
        transaction { short_link_mutations.update(link.id, destination:, retargeted_at: Time.now) }
        short_link_queries.find(link.id)
      end
    end
  end
end
