# frozen_string_literal: true

module Shares
  module Relations
    class ShortCodes < Blog::DB::Relation
      schema :short_codes, infer: true
    end
  end
end
