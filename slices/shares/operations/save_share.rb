# frozen_string_literal: true

module Shares
  module Operations
    class SaveShare < Blog::Operation
      include Deps["operations.change_share_code", "operations.set_share_alt_text"]

      def call(id, params)
        transaction do
          share = step change_share_code.call(id, params)
          params.key?(:alt_text) ? step(set_share_alt_text.call(id, params)) : share
        end
      end
    end
  end
end
