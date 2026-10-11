# frozen_string_literal: true

module Shares
  module Repos
    class ShareQueries < Blog::DB::Repo
      def by_code(code) = shares.with_code.where(Sequel[:short_codes][:code] => code).one

      def find(id) = shares.with_code.by_pk(id).one
    end
  end
end
