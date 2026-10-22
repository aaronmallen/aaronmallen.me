# frozen_string_literal: true

module Security
  module Repos
    class SignInQueries < Blog::DB::Repo
      def page(page) = page.fill(sign_ins.outside_devices.newest_first.paged(page).to_a)
    end
  end
end
