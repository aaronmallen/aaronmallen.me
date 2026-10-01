# frozen_string_literal: true

module Analytics
  module Contracts
    class VisitContract < Blog::Contract
      MAX_PATH = 2048
      MAX_TITLE = 512
      MISSING = "missing"
      PATH = %r{\A/\S*\z}
      READ = "read"
      REF = Analytics::Ref::KEY.to_sym
      SCROLL = "scroll"
      TOKEN = /\A[0-9a-f]{32}\z/
      VIEW = "view"
      KINDS = [READ, SCROLL, VIEW].freeze

      json do
        required(:kind).value(:string, included_in?: KINDS)
        required(:path).value(:string, max_size?: MAX_PATH, format?: PATH)
        optional(:title).value(:string, max_size?: MAX_TITLE)
        optional(:referrer).value(:string)
        optional(:read_seconds).value(:integer, gteq?: 0)
        optional(:scroll_depth).value(:integer, included_in?: Analytics::Scroll::DEPTHS)
        optional(:view_token).value(:string, format?: TOKEN)
        optional(REF).maybe(:string)
      end

      rule(:path).validate(:without_controls)
      rule(:title).validate(:without_controls)

      rule(:kind, :read_seconds) do
        key(:read_seconds).failure(MISSING) if values[:kind] == READ && values[:read_seconds].nil?
      end

      rule(:kind, :scroll_depth) do
        key(:scroll_depth).failure(MISSING) if values[:kind] == SCROLL && values[:scroll_depth].nil?
      end

      rule(:kind, :view_token) do
        key(:view_token).failure(MISSING) if values[:kind] != VIEW && values[:view_token].nil?
      end
    end
  end
end
