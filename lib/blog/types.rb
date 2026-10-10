# frozen_string_literal: true

require "digest"
require "dry/types"
require "ipaddr"
require "securerandom"
require "uri"

module Blog
  Types = Dry.Types(default: :strict)

  module Types
    CHECKED = "1"
    GAP = :gap
    INTEGER_MAX = (2**31) - 1
    IPV6_PREFIX = 64
    REDIRECT_HOSTS = {
      "http" => ->(uri) { %w[127.0.0.1 ::1 localhost].include?(uri.hostname) },
      "https" => ->(uri) { !uri.hostname.to_s.empty? },
    }.freeze
    SECRET_BYTES = 32
    SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
    SLUG_RESERVED = %w[tags].freeze
    URL_FORMAT = %r{https?://[^\s/?#]+(?:[/?#]\S*)?}
    private_constant :IPV6_PREFIX, :REDIRECT_HOSTS, :SECRET_BYTES, :SLUG_FORMAT, :SLUG_RESERVED, :URL_FORMAT

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
      "decision", "decision_comment", "session", "pull_request_opened", "pull_request_merged", "pull_request_closed",
    )
    ActivityScreenKind = Types::String.enum(*ActivityKind.values - %w[project sprint suggestion])
    AnalyticsRange = Types::Params::Integer.enum(7, 14, 30)
    AnalyticsRangeParam = AnalyticsRange.fallback(30)
    AttentionKind = Types::String.enum("carried", "draft", "someday", "journal", "new_device")
    Checkbox = Types::Bool.constructor { |value| value == CHECKED }
    CodeChallengeMethod = Types::String.enum("S256")
    ContributorKind = Types::String.enum("owner", "agent")
    ContributorSlug = Types::String.constrained(format: /\A[a-z0-9]+(?:[.-][a-z0-9]+)*\z/, max_size: 64)
    Contributor = [
      { kind: Types::String.constrained(eql: "owner") },
      { kind: Types::String.constrained(eql: "agent"), agent: ContributorSlug, model: ContributorSlug },
    ].map { Types::Hash.schema(it).strict.with_key_transform(&:to_sym) }.reduce(:|)
    CountryCode = Types::String.constrained(format: /\A[A-Z]{2}\z/)
    DateParam = Types::Params::Date.constrained(
      gteq: ::Date.new(1000), lteq: ::Date.new(9999, 12, 31),
    ).optional.fallback(nil)
    DecisionEventKind = Types::String.enum(
      "opened", "option_added", "option_edited", "edited", "resolved", "dropped", "reopened",
    )
    DecisionStatus = Types::String.enum("open", "resolved", "dropped")
    DecisionStatusParam = DecisionStatus.fallback(DecisionStatus.values.first)
    DecisionTimelineKind = Types::String.enum("comment", *DecisionEventKind.values)
    DeviceClass = Types::String.enum("desktop", "mobile", "tablet", "in-app")
    Fields = Types::Hash.constructor { |value| value.is_a?(::Hash) ? value : Blog::Constants::EMPTY_HASH }
    Id = Types::Params::Integer.constrained(gt: 0, lt: 2**31)
    IdList = Types::Array.of(Id).constructor { |ids| ids.is_a?(::Array) ? ids.uniq : ids }
    IdParam = Id.optional.fallback(nil)
    IssuedSecret = Types::String.constrained(format: /\A[A-Za-z0-9_-]{43}\z/)
    NewSecret = IssuedSecret.default { SecureRandom.urlsafe_base64(SECRET_BYTES) }
    LocalTime = Types::Instance(Object).constructor do |value|
      text = TrimmedText[value]
      next nil if text.empty?

      TimeZone.parse_input(text) || text
    rescue TZInfo::PeriodNotFound
      GAP
    end
    MarkdownRenderer = Types::String.enum("posts", "tasks")
    MessageBulkAction = Types::String.enum("read", "unread", "tag", "untag", "delete")
    MessageFilter = Types::String.enum("unread", "read", "spam", "inbox")
    MessageFilterParam = MessageFilter.fallback(MessageFilter.values.first)
    MessageStatus = Types::String.enum("unread", "read", "spam")
    NetworkName = Types::String.enum("mastodon", "bluesky")
    OAuthDecision = Types::String.enum("cancel", "approve")
    OAuthDecisionParam = OAuthDecision.fallback(OAuthDecision.values.first)
    OAuthGrantType = Types::String.enum("authorization_code", "refresh_token")
    OAuthResponseType = Types::String.enum("code")
    OAuthScope = Types::String.enum("read", "suggest", "write", "publish", "delete")
    OAuthTokenAuthMethod = Types::String.enum("none")
    OAuthTokenType = Types::String.enum("access", "refresh")
    OptionalText = Types::String.optional.constructor do |value|
      text = TrimmedText[value]
      text.empty? ? nil : text
    end
    PageNumber = Types::Params::Integer.constrained(gt: 0, lt: 2**31)
    PageParam = PageNumber.constructor { |value| value.nil? ? 1 : value }
    PKCEValue = Types::String.constrained(format: /\A[A-Za-z0-9\-._~]{43,128}\z/)
    PhotoType = Types::String.enum(
      "gif" => "image/gif", "jpg" => "image/jpeg", "png" => "image/png", "webp" => "image/webp",
    )
    PhotoKey = Types::String.constrained(format: /\A[0-9a-f]{32}\.(?:#{PhotoType.values.join('|')})\z/)
    PhotoOwner = Types::String.enum("post", "journal_entry", "task", "task_comment", "decision_comment", "review_note")
    PostBulkAction = Types::String.enum("tag", "delete")
    PostStatus = Types::String.enum("draft", "scheduled", "published")
    PostFilter = Types::String.enum("all", *PostStatus.values)
    PostFilterParam = PostFilter.fallback(PostFilter.values.first)
    PostFollowUp = Types::String.enum("syndicate_post", "send_webmentions")
    PostIntent = Types::String.enum("draft", "publish", "save")
    PostIntentParam = PostIntent.fallback(PostIntent.values.first)
    ProjectFilter = Types::String.enum("live", "archived", "work")
    ProjectFilterParam = ProjectFilter.fallback(ProjectFilter.values.first)
    ProjectMonth = Types::String.constrained(format: /\A\d{4}-(?:0[1-9]|1[0-2])\z/)
    ProjectVisibility = Types::String.enum("public", "private")
    PullRequestState = Types::String.enum("draft", "open", "merged", "closed")
    RangePreset = Types::Integer.enum(7, 30, 90)
    RecordKind = Types::String.enum(*%w[task post social_post journal_entry commit project work_entry decision
                                        pull_request])
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
    RepoPattern = Types::String.constrained(format: %r{\A[a-z0-9][a-z0-9-]*/(?:\*|[a-z0-9._-]+)\z})
    ReviewGroup = Types::String.enum("tag", "project")
    ReviewGroupParam = ReviewGroup.fallback(ReviewGroup.values.first)
    ReviewPeriod = Types::String.enum("week", "month")
    ReviewPeriodParam = ReviewPeriod.fallback(ReviewPeriod.values.first)
    SavedViewScreen = Types::String.enum("activity", "journal", "posts", "tasks")
    ScrollDepth = Types::Integer.enum(0, 25, 50, 75, 100)
    SecretDigest = Types::String.constructor { |value| Digest::SHA256.hexdigest(value.to_s) }
    SearchKind = Types::String.enum(
      "task", "post", "social", "journal", "commit", "project", "work", "person", "message", "webmention", "decision",
      "pull_request",
    )
    SearchKindParam = SearchKind.optional.fallback(nil)
    Slug = Types::String.constrained(format: SLUG_FORMAT, excluded_from: SLUG_RESERVED)
    SocialIntent = Types::String.enum("draft", "send")
    SocialIntentParam = SocialIntent.fallback(SocialIntent.values.first)
    SocialMode = Types::String.enum("now", "schedule")
    SocialModeParam = SocialMode.fallback(SocialMode.values.first)
    SocialPostStatus = Types::String.enum("draft", "scheduled", "posted")
    SocialQueue = Types::String.enum("queued", "posted", "drafts")
    SocialQueueParam = SocialQueue.fallback(SocialQueue.values.first)
    SuggestionEditStatus = Types::String.enum("pending", "accepted", "rejected", "stale")
    SyncName = Types::String.enum(
      "analytics_rollup", "commits", "country_database", "projects", "issues", "linear_issues", "backups",
      "pull_requests",
    )
    SyncStateKind = Types::String.enum("commits", "backfill", "failure")
    Tag = Types::String.constrained(format: SLUG_FORMAT)
    TagColor = Types::String.enum("mk-pink", "mk-green", "mk-blue", "mk-violet", "mk-sand", "mk-orange")
    TagList = Types::Array.of(Types::String).constructor do |tags|
      tags.to_s.split(",").map { Normalizers::Tag[it] }.reject(&:empty?).uniq
    end
    TagScope = Types::String.enum("public", "private")
    TagScopeParam = TagScope.fallback(TagScope.values.first)
    TaskAct = Types::String.enum("complete", "pause")
    TaskActParam = TaskAct.fallback(TaskAct.values.first)
    TaskBulkAction = Types::String.enum("complete", "cancel", "move", "tag", "untag", "delete")
    TaskFilter = Types::String.enum("today", "next", "someday", "external")
    TaskFilterParam = TaskFilter.fallback(TaskFilter.values.first)
    TaskLinkType = Types::String.enum("blocks", "relates", "duplicates", "parent")
    TaskLinkKind = Types::String.enum("blocks", "relates", "duplicates", "blocked_by")
    TaskList = Types::String.enum("next", "someday", "external")
    TaskListParam = TaskList.fallback(TaskList.values.first)
    TaskMove = Types::String.enum("up", "down")
    TaskOrigin = Types::String.enum("tasks", "today", "inbox")
    TaskOriginParam = TaskOrigin.fallback(TaskOrigin.values.first)
    TaskSourceProvider = Types::String.enum("github", "linear")
    TaskSourceState = Types::String.enum(*%w[open completed not_planned unassigned moved deleted started])
    TaskStatus = Types::String.enum("open", "in_progress", "done", "canceled")
    TaskTimelineKind = Types::String.enum("comment", "session", "moved", "tagged", "untagged", "status_changed")
    TaskView = Types::String.enum("today", "upcoming", "next", "someday", "external")
    TaskTab = Types::String.enum(*TaskView.values, "completed")
    TaskTabParam = TaskTab.fallback(TaskTab.values.first)
    Text = Types::String.constructor { |value| value.is_a?(::String) ? value : Blog::Constants::EMPTY_STRING }
    TextList = Types::Array.of(Types::String).constructor do |values|
      [*values].map { TrimmedText[it] }.reject(&:empty?)
    end
    TimeGrouping = Types::String.enum("tag", "project", "day")
    TimeGroupingParam = TimeGrouping.fallback(TimeGrouping.values.first)
    ThrottleKey = Types::String.constructor do |address|
      ip = IPAddr.new(address).native
      ip.ipv6? ? ip.mask(IPV6_PREFIX).to_s : ip.to_s
    rescue IPAddr::Error
      address
    end
    TrimmedText = Text.constructor(&:strip)
    UploadParam = Types::Interface(:read, :rewind, :size).optional.constructor do |value|
      value[:tempfile] if value.is_a?(::Hash)
    end
    Url = Types::String.constrained(format: /\A#{URL_FORMAT}\z/)
    UrlOrBlank = Types::String.constrained(format: /\A(?:#{URL_FORMAT})?\z/).constructor { |value| TrimmedText[value] }
    Uuid = Types::String.constrained(format: /\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/)
    UuidParam = Uuid.optional.fallback(nil)
    VisitKind = Types::String.enum("click", "read", "scroll", "view")
    VisitorHash = Types::String.constrained(format: /\A[0-9a-f]{64}\z/)
    WebmentionModeration = Types::String.enum("approved" => "approve", "ignored" => "ignore", "spam" => "spam")
    WebmentionStatus = Types::String.enum("pending", "approved", "ignored", "spam")
    WebmentionStatusParam = WebmentionStatus.fallback(WebmentionStatus.values.first)
    WebmentionType = Types::String.enum("reply", "like", "repost", "mention")
    WebmentionVerdict = Types::String.enum("approved", "ignored", "spam")
    Year = Types::String.constrained(format: /\A[1-9]\d{3}\z/)

    module Normalized
      ContributorKind = Types::ContributorKind.constructor { |value| Normalizers::Tag[value.to_s] }
      ContributorSlug = Types::ContributorSlug.constructor { |value| Normalizers::Tag[value.to_s] }
      GithubRepo = Types::Repo.constructor { |url| Normalizers::Repo[url.to_s.strip[%r{\Ahttps?://(?:www\.)?github\.com/([a-z0-9][a-z0-9-]*/[a-z0-9._-]+?)(?:\.git)?/?\z}i, 1]] }
      Host = Types::String.constructor do |url|
        URI.parse(Normalizers::Url[url]).hostname.to_s.downcase
      rescue URI::Error
        Blog::Constants::EMPTY_STRING
      end.constrained(format: %r{\A[^\s/?#@]+\z})
      Hosts = Types::Array.of(Types::String).constructor do |values|
        entries = (values.is_a?(::Array) ? values.map(&:to_s) : values.to_s.split(/[\r\n,]+/)).map(&:strip)

        entries.filter_map { Host.call(it.include?("://") ? it : "https://#{it}") { nil } }.uniq.sort
      end
      LabelTag = Types::Tag.constructor do |label|
        Hanami.app.inflector.underscore(label.to_s).gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
      end
      Lines = Types::String.constructor { |text| TrimmedText[text].gsub(/\r\n?/, "\n") }
      Networks = Types::Array.of(Types::NetworkName).constructor do |names|
        found = [*names].map(&:to_s)

        Types::NetworkName.values.select { found.include?(it) }
      end
      RefSource = Types::String.constructor { |value| value.to_s.strip.downcase }.constrained(
        format: /\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/, max_size: 32,
      )
      Repo = Types::Repo.constructor { |value| Normalizers::Repo[value] }
      RepoPattern = Types::RepoPattern.constructor { |value| Normalizers::Repo[value] }
      Slug = Types::String.constructor do |text|
        text.to_s.unicode_normalize(:nfkd).gsub(/\p{M}/, "").downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
      end.constrained(format: SLUG_FORMAT)
      Tag = Types::Tag.constructor { |text| Normalizers::Tag[text] }
      Url = Types::Url.constructor { |url| Normalizers::Url[url] }
    end

    module Nullable
      Repo = Types::Repo.optional.constructor { |value| OptionalText[value] }
      Slug = Types::Slug.optional.constructor { |value| OptionalText[value] }
      Tag = Types::String.optional.constructor { |value| OptionalText[value]&.then { Normalizers::Tag[it] } }
      TagColor = Types::TagColor.optional.constructor { |value| OptionalText[value] }
      TaskFilter = Types::TaskFilter.optional.constructor { |value| OptionalText[value] }
      Url = Types::Url.optional.constructor { |value| OptionalText[value] }
    end
  end
end
