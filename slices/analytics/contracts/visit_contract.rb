# frozen_string_literal: true

module Analytics
  module Contracts
    class VisitContract < Blog::Contract
      CLICK = Blog::Types::VisitKind["click"]
      HOST = /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\z/
      LINK_PATH = %r{\A/[^\s?#]*\z}
      MAX_HOST = 253
      MAX_PATH = 2048
      MAX_TITLE = 512
      MISSING = "missing"
      PATH = %r{\A/\S*\z}
      READ = Blog::Types::VisitKind["read"]
      REF = Analytics::Ref::KEY.to_sym
      SCROLL = Blog::Types::VisitKind["scroll"]
      TOKEN = /\A[0-9a-f]{32}\z/
      VIEW = Blog::Types::VisitKind["view"]

      json do
        required(:kind).value(:string, included_in?: Blog::Types::VisitKind.values)
        required(:path).value(:string, max_size?: MAX_PATH, format?: PATH)
        optional(:title).value(:string, max_size?: MAX_TITLE)
        optional(:referrer).value(:string)
        optional(:read_seconds).value(:integer, gteq?: 0)
        optional(:scroll_depth).value(:integer, included_in?: Analytics::Scroll::DEPTHS)
        optional(:link_host).value(:string, max_size?: MAX_HOST, format?: HOST)
        optional(:link_path).value(:string, max_size?: MAX_PATH, format?: LINK_PATH)
        optional(:view_token).value(:string, format?: TOKEN)
        optional(REF).maybe(:string)
      end

      rule(:link_path).validate(:without_controls)
      rule(:path).validate(:without_controls)
      rule(:title).validate(:without_controls)

      rule(:kind, :link_host) do
        key(:link_host).failure(MISSING) if values[:kind] == CLICK && values[:link_host].nil?
      end

      rule(:kind, :link_path) do
        key(:link_path).failure(MISSING) if values[:kind] == CLICK && values[:link_path].nil?
      end

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
