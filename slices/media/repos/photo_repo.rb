# frozen_string_literal: true

module Media
  module Repos
    class PhotoRepo < Blog::DB::Repo
      commands :create
    end
  end
end
