# frozen_string_literal: true

module Shares
  module Repos
    class ShortCodeQueries < Blog::DB::Repo
      OWNED = %i[share_group_files share_groups short_links].freeze
      OWNERS = [
        Sequel[:share_group_files][:id].as(:share_id), Sequel[:share_groups][:id].as(:share_group_id),
        Sequel[:short_links][:destination],
      ].freeze

      def owner(code)
        id = Sequel[:short_codes][:id]
        found = short_codes.dataset.unordered.where(id => short_codes.resolved_id(code))
        found = OWNED.reduce(found) { |owned, table| owned.left_join(table, short_code_id: id) }
        found.select(*OWNERS).first
      end
    end
  end
end
