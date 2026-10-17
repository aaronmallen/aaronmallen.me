# frozen_string_literal: true

module Shares
  module Relations
    class ShareGroups < Blog::DB::Relation
      use :short_coded

      schema :share_groups, infer: true do
        associations do
          belongs_to :short_code
          has_many :share_group_files
        end
      end
    end
  end
end
