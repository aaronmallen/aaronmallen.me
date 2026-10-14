# frozen_string_literal: true

module Shares
  module Relations
    class ShareGroupFiles < Blog::DB::Relation
      schema :share_group_files, infer: true do
        associations do
          belongs_to :share_group
        end
      end
    end
  end
end
