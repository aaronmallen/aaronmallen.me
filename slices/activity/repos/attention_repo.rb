# frozen_string_literal: true

module Activity
  module Repos
    class AttentionRepo < Blog::DB::Repo
      def stalled(on:, **limits) = attention.stalled(on:, **limits).to_a
    end
  end
end
