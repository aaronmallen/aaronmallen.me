# frozen_string_literal: true

module Shares
  module Repos
    class ShortLinkQueries < Blog::DB::Repo
      def by_code(code) = short_links.with_code.where(Sequel[:short_codes][:code] => code).one

      def find(id) = short_links.with_code.by_pk(id).one
    end
  end
end
