# frozen_string_literal: true

require "dry/types"
require "uri"

module Blog
  Types = Dry.Types(default: :strict)

  module Types
    REDIRECT_HOSTS = {
      "http" => ->(uri) { %w[127.0.0.1 ::1 localhost].include?(uri.hostname) },
      "https" => ->(uri) { !uri.hostname.to_s.empty? },
    }.freeze
    SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
    URL_FORMAT = %r{https?://[^\s/?#]+(?:[/?#]\S*)?}
    private_constant :REDIRECT_HOSTS, :SLUG_FORMAT, :URL_FORMAT

    module Normalizers
      Repo = Types::Any.constructor { |value| value.to_s.strip.downcase }

      Tag = Types::Any.constructor { |text| text.strip.downcase }

      Url = Types::Any.constructor do |url|
        uri = URI.parse(url.to_s.strip)
        userinfo = uri.userinfo
        uri.scheme = uri.scheme.downcase if uri.scheme
        uri.host = uri.host.downcase if uri.host
        uri.userinfo = userinfo if userinfo
        uri.fragment = nil
        uri.path = uri.path.chomp("/") if uri.path.to_s.length > 1
        uri.to_s
      rescue URI::Error
        url.to_s
      end
    end
    private_constant :Normalizers

    ActivityKind = Types::String.enum(
      "commit", "post", "journal", "social", "task", "webmention", "project", "sprint", "suggestion", "comment",
    )
    AnalyticsRange = Types::Params::Integer.enum(7, 14, 30)
    AnalyticsRangeParam = AnalyticsRange.fallback(AnalyticsRange.values.first)
    Checkbox = Types::Bool.constructor { |value| value == Constants::CHECKED }
    CountryCode = Types::String.constrained(format: /\A[A-Z]{2}\z/)
    DateParam = Types::Params::Date.optional.fallback(nil)
    Fields = Types::Hash.constructor { |value| value.is_a?(::Hash) ? value : Blog::Constants::EMPTY_HASH }
    Id = Types::Params::Integer.constrained(gt: 0)
    IdParam = Id.optional.fallback(nil)
    LocalTime = Types::Instance(Object).constructor do |value|
      text = TrimmedText[value]
      next nil if text.empty?

      TimeZone.parse_input(text) || text
    rescue TZInfo::PeriodNotFound
      Constants::GAP
    end
    MarkdownRenderer = Types::String.enum("posts", "tasks")
    MessageStatus = Types::String.enum("unread", "read", "spam")
    MessageStatusParam = MessageStatus.fallback(MessageStatus.values.first)
    NetworkName = Types::String.enum("mastodon", "bluesky")
    OAuthDecision = Types::String.enum("cancel", "approve")
    OAuthDecisionParam = OAuthDecision.fallback(OAuthDecision.values.first)
    OptionalText = Types::String.optional.constructor do |value|
      text = TrimmedText[value]
      text.empty? ? nil : text
    end
    PageNumber = Types::Params::Integer.constrained(gt: 0, lt: 2**31)
    PageParam = PageNumber.constructor { |value| value.nil? ? 1 : value }
    PostStatus = Types::String.enum("draft", "scheduled", "published")
    PostFilter = Types::String.enum("all", *PostStatus.values)
    PostFilterParam = PostFilter.fallback(PostFilter.values.first)
    PostIntent = Types::String.enum("draft", "publish", "save")
    PostIntentParam = PostIntent.fallback(PostIntent.values.first)
    ProjectFilter = Types::String.enum("live", "archived", "work")
    ProjectFilterParam = ProjectFilter.fallback(ProjectFilter.values.first)
    ProjectLiveStatus = Types::String.enum("active", "wip", "paused")
    ProjectMonth = Types::String.constrained(format: /\A\d{4}-(?:0[1-9]|1[0-2])\z/)
    ProjectMove = Types::String.enum("up", "down")
    ProjectStatus = Types::String.enum(*ProjectLiveStatus.values, "archived")
    RedirectUri = Types::String.constructor do |value|
      next Blog::Constants::EMPTY_STRING unless value.is_a?(::String)

      trimmed = value.strip
      uri = URI.parse(trimmed)
      host_allowed = REDIRECT_HOSTS[uri.scheme]
      usable = host_allowed && uri.userinfo.nil? && uri.fragment.nil? && host_allowed.call(uri)

      usable ? trimmed : Blog::Constants::EMPTY_STRING
    rescue URI::InvalidURIError
      Blog::Constants::EMPTY_STRING
    end.constrained(min_size: 1)
    Repo = Types::String.constrained(format: %r{\A[a-z0-9][a-z0-9-]*/[a-z0-9._-]+\z})
    Slug = Types::String.constrained(format: SLUG_FORMAT, excluded_from: Constants::SLUG_RESERVED)
    SocialIntent = Types::String.enum("draft", "send")
    SocialIntentParam = SocialIntent.fallback(SocialIntent.values.first)
    SocialMode = Types::String.enum("now", "schedule")
    SocialModeParam = SocialMode.fallback(SocialMode.values.first)
    SocialPostStatus = Types::String.enum("draft", "scheduled", "posted")
    SocialQueue = Types::String.enum("queued", "posted", "drafts")
    SocialQueueParam = SocialQueue.fallback(SocialQueue.values.first)
    Tag = Types::String.constrained(format: SLUG_FORMAT)
    TagColor = Types::String.enum("mk-pink", "mk-green", "mk-blue", "mk-violet", "mk-sand", "mk-orange")
    TagList = Types::Array.of(Types::String).constructor do |tags|
      tags.to_s.split(",").map { Normalizers::Tag[it] }.reject(&:empty?).uniq
    end
    TagScope = Types::String.enum("public", "private")
    TagScopeParam = TagScope.fallback(TagScope.values.first)
    TaskFilter = Types::String.enum("today", "next", "someday", "external")
    TaskFilterParam = TaskFilter.fallback(TaskFilter.values.first)
    TaskLinkType = Types::String.enum("blocks", "relates", "duplicates")
    TaskLinkKind = Types::String.enum(*TaskLinkType.values, "blocked_by")
    TaskList = Types::String.enum("next", "someday", "external")
    TaskListParam = TaskList.fallback(TaskList.values.first)
    TaskMove = Types::String.enum("up", "down")
    TaskOrigin = Types::String.enum("tasks", "today")
    TaskOriginParam = TaskOrigin.fallback(TaskOrigin.values.first)
    TaskSourceProvider = Types::String.enum("github", "linear")
    TaskSourceState = Types::String.enum(*%w[open completed not_planned unassigned moved deleted started])
    TaskStatus = Types::String.enum("open", "in_progress", "done", "canceled")
    TaskView = Types::String.enum("today", "upcoming", "next", "someday", "external")
    TaskTab = Types::String.enum(*TaskView.values, "completed")
    TaskTabParam = TaskTab.fallback(TaskTab.values.first)
    Text = Types::String.constructor { |value| value.is_a?(::String) ? value : Blog::Constants::EMPTY_STRING }
    TextList = Types::Array.of(Types::String).constructor do |values|
      [*values].map { TrimmedText[it] }.reject(&:empty?)
    end
    TrimmedText = Text.constructor(&:strip)
    UploadParam = Types::Interface(:read, :rewind, :size).optional.constructor do |value|
      value[:tempfile] if value.is_a?(::Hash)
    end
    Url = Types::String.constrained(format: /\A#{URL_FORMAT}\z/)
    UrlOrBlank = Types::String.constrained(format: /\A(?:#{URL_FORMAT})?\z/).constructor { |value| TrimmedText[value] }
    Uuid = Types::String.constrained(format: /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/)
    UuidParam = Uuid.optional.fallback(nil)
    VisitorHash = Types::String.constrained(format: /\A[0-9a-f]{64}\z/)
    WebmentionStatus = Types::String.enum("pending", "approved", "ignored", "spam")
    WebmentionStatusParam = WebmentionStatus.fallback(WebmentionStatus.values.first)
    WebmentionType = Types::String.enum("reply", "like", "repost", "mention")
    Year = Types::String.constrained(format: /\A[1-9]\d{3}\z/)

    module Normalized
      GithubRepo = Types::Repo.constructor { |url| Normalizers::Repo[url.to_s.strip[%r{\Ahttps?://(?:www\.)?github\.com/([a-z0-9][a-z0-9-]*/[a-z0-9._-]+?)(?:\.git)?/?\z}i, 1]] }
      Host = Types::String.constructor do |url|
        URI.parse(Normalizers::Url[url]).hostname.to_s.downcase
      rescue URI::Error
        Blog::Constants::EMPTY_STRING
      end.constrained(format: %r{\A[^\s/?#@]+\z})
      LabelTag = Types::Tag.constructor do |label|
        Hanami.app.inflector.underscore(label.to_s).gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
      end
      Networks = Types::Array.of(Types::NetworkName).constructor do |names|
        found = [*names].map(&:to_s)

        Types::NetworkName.values.select { found.include?(it) }
      end
      Repo = Types::Repo.constructor { |value| Normalizers::Repo[value] }
      Slug = Types::String.constructor do |text|
        text.to_s.unicode_normalize(:nfkd).gsub(/\p{M}/, "").downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
      end.constrained(format: SLUG_FORMAT)
      Tag = Types::Tag.constructor { |text| Normalizers::Tag[text] }
      Url = Types::Url.constructor { |url| Normalizers::Url[url] }
    end

    module Nullable
      ProjectLiveStatus = Types::ProjectLiveStatus.optional.constructor { |value| OptionalText[value] }
      Repo = Types::Repo.optional.constructor { |value| OptionalText[value] }
      Slug = Types::Slug.optional.constructor { |value| OptionalText[value] }
      TagColor = Types::TagColor.optional.constructor { |value| OptionalText[value] }
      TaskFilter = Types::TaskFilter.optional.constructor { |value| OptionalText[value] }
      Url = Types::Url.optional.constructor { |value| OptionalText[value] }
    end
  end
end
