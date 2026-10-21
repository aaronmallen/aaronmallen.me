# frozen_string_literal: true

module Shares
  module Relations
    class ShortCodes < Blog::DB::Relation
      schema :short_codes, infer: true

      def resolved_id(path) = dataset.unordered.where(code: path).select(:id)
    end
  end
end
