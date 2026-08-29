# frozen_string_literal: true

RSpec.describe "Accepting suggested edits", type: :request do
  let(:post_repo) { Posts::Slice["repos.post_repo"] }
  let(:social_post_repo) { Social::Slice["repos.social_post_repo"] }
  let(:suggestion_repo) { Suggestions::Slice["repos.suggestion_repo"] }

  def accept(article) = post("/admin/posts/#{article.id}/suggestions/accept", _csrf_token: admin_csrf_token)

  def accept_social(social_post)
    post "/admin/social/#{social_post.id}/suggestions/accept", _csrf_token: admin_csrf_token
  end

  def bodies_of(social_post) = social_post_repo.by_id(social_post.id).parts.map(&:body)

  def body_of(article) = post_repo.by_id(article.id).body

  def compose(*parts)
    social_post_repo.create_with_parts(parts:, posted_at: nil, status: "draft", targets: %w[mastodon])
  end

  def statuses(article) = suggestion_repo.for_post(article.id).edits.map(&:status)

  def suggest(article, *edits) = suggestion_repo.replace_for_post(article.id, edits)

  def suggest_social(social_post, *edits) = suggestion_repo.replace_for_social_post(social_post.id, edits)

  def typo(original = "teh", replacement = "the") = { original:, replacement:, reason: "typo" }

  before do
    connect_social_networks
    sign_in_to_admin
  end

  describe "an edit whose text appears twice in a post" do
    let(:article) { create(:post, :draft, body: "teh cat and teh dog") }

    before do
      suggest(article, typo)
      accept(article)
    end

    it "is refused as stale" do
      expect(statuses(article)).to eq(%w[stale])
    end

    it "leaves the body alone" do
      expect(body_of(article)).to eq("teh cat and teh dog")
    end
  end

  describe "an edit whose text appears twice in a social post's part" do
    let(:social_post) { compose("teh cat and teh dog") }

    before do
      suggest_social(social_post, { **typo, part: 1 })
      accept_social(social_post)
    end

    it "is refused as stale" do
      expect(suggestion_repo.for_social_post(social_post.id).edits.map(&:status)).to eq(%w[stale])
    end

    it "leaves the part alone" do
      expect(bodies_of(social_post)).to eq(["teh cat and teh dog"])
    end
  end

  describe "an edit whose text appears once" do
    it "replaces that text and nothing around it" do
      article = create(:post, :draft, body: "one teh two teh three")
      suggest(article, typo("teh two", "the two"))
      accept(article)

      expect(body_of(article)).to eq("one the two teh three")
    end

    it "takes a replacement that reads like a backreference as it stands" do
      article = create(:post, :draft, body: "call \\1 back")
      suggest(article, typo("\\1", "\\2"))
      accept(article)

      expect(body_of(article)).to eq("call \\2 back")
    end

    it "applies beside an edit that went stale" do
      article = create(:post, :draft, body: "teh cat and teh dog sat")
      suggest(article, typo, typo("sat", "slept"))
      accept(article)

      expect(body_of(article)).to eq("teh cat and teh dog slept")
    end
  end

  describe "a newer set of edits that lands while an accept is on its way" do
    let(:article) { create(:post, :draft, body: "teh cat sat") }

    before do
      suggest(article, typo)
      inner = Suggestions::Slice["queries.for_post"]
      replace_component(
        "suggestions.queries.for_post",
        ->(id) { inner.call(id).tap { suggestion_repo.replace_for_post(id, [typo("sat", "slept")]) } },
      )
      accept(article)
    end

    it "returns to the editor" do
      expect(last_response).to be_redirect.and have_attributes(location: "/admin/posts/#{article.id}/edit")
    end

    it "leaves the body alone" do
      expect(body_of(article)).to eq("teh cat sat")
    end

    it "leaves the newer edits pending" do
      expect(statuses(article)).to eq(%w[pending])
    end
  end

  describe "the rows an accept holds", :commits do
    let(:database) { Suggestions::Slice["db.rom"].gateways[:default].connection }
    let(:held) { [] }

    def ahead_of(key, &)
      inner = Suggestions::Slice[key]
      replace_component(key, ->(id) { yield(id).then { inner.call(id) } })
    end

    def nowait(table, id)
      Thread.new do
        Thread.current.report_on_exception = false
        database[table].where(id:).for_update.nowait.to_a
      end.join
      :free
    rescue Sequel::DatabaseError
      :held
    end

    def probing(key, &)
      inner = Suggestions::Slice[key]
      replace_component(key, ->(id) { inner.call(id).tap { held << yield(id) } })
    end

    def rival_update(table, id, **changes)
      rival = Sequel.connect(database.opts.merge(max_connections: 1))
      rival.run("SET statement_timeout = '1s'")
      rival[table].where(id:).update(**changes)
      :free
    rescue Sequel::DatabaseError
      :held
    ensure
      rival&.disconnect
    end

    it "holds the post before it reads the body" do
      article = create(:post, :draft, body: "teh cat sat")
      suggest(article, typo)
      probing("posts.operations.lock_post") { nowait(:posts, it) }
      accept(article)

      expect(held).to eq([:held])
    end

    it "holds the social post before it reads the parts" do
      social_post = compose("teh first")
      suggest_social(social_post, { **typo, part: 1 })
      probing("social.operations.lock_editable_social_post") { nowait(:social_posts, it) }
      accept_social(social_post)

      expect(held).to eq([:held])
    end

    it "keeps out a rival write that lands between the read and the save", :aggregate_failures do
      article = create(:post, :draft, body: "teh cat sat")
      suggest(article, typo)
      probing("posts.operations.lock_post") { rival_update(:posts, it, body: "teh cat sat on the mat") }
      accept(article)

      expect([held, body_of(article)]).to eq([[:held], "the cat sat"])
    end

    it "answers with a redirect rather than an error when the post is deleted under it" do
      article = create(:post, :draft, body: "teh cat sat")
      suggest(article, typo)
      ahead_of("posts.operations.lock_post") { |id| Thread.new { post_repo.posts.by_pk(id).delete }.join }
      accept(article)

      expect(last_response).to be_redirect.and have_attributes(location: "/admin/posts/#{article.id}/edit")
    end
  end
end
