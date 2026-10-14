# frozen_string_literal: true

module Shares
  module Relations
    class ShareGroups < Blog::DB::Relation
      schema :share_groups, infer: true do
        associations do
          belongs_to :short_code
          has_many :share_group_files
        end
      end

      def with_code = qualified.join(:short_codes).select_append { |short_codes:| short_codes[:code] }
    end
  end
end
