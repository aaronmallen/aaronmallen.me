# frozen_string_literal: true

module Shares
  module Relations
    class ShortLinks < Blog::DB::Relation
      schema :short_links, infer: true do
        associations do
          belongs_to :short_code
        end
      end

      def with_code = qualified.join(:short_codes).select_append { |short_codes:| short_codes[:code] }
    end
  end
end
