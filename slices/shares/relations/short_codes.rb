# frozen_string_literal: true

module Shares
  module Relations
    class ShortCodes < Blog::DB::Relation
      schema :short_codes, infer: true

      def resolved_id(path)
        exact = Sequel.case({ { code: path } => 0 }, 1)
        prefixed = dataset.unordered.where(Sequel.like(:code, "#{dataset.escape_like(path)}%"))
        prefixed.order(exact, :id).limit(1).select(:id)
      end
    end
  end
end
