# frozen_string_literal: true

RSpec.describe "MCP suggestion tools", type: :request do
  def accept_first(read)
    edit_ids = [read.dig("suggestion_edits", 0, "id")]
    mcp_call("accept_suggestion_edits", suggestion_id: read.fetch("suggestion_id"), edit_ids:)
  end

  def compose(status, *parts, posted_at: nil, targets: %w[mastodon])
    Social::Slice["repos.social_post_repo"].create_with_parts(parts:, posted_at:, status:, targets:)
  end

  def edit(original, replacement, part: nil) = { original:, replacement:, reason: "typo", part: }

  def post_body(id) = Posts::Slice["repos.post_repo"].by_id(id).body

  def statuses(suggestion) = suggestion_repo.by_id(suggestion.id).edits.map(&:status)

  def suggest(post, *edits) = suggestion_repo.replace_for_post(post.id, edits)

  def suggestion_repo = Suggestions::Slice["repos.suggestion_repo"]

  def today = Blog::TimeZone.today

  describe "list_suggestions" do
    def listed(from: today, to: today)
      mcp_answer("list_suggestions", from: from.iso8601, to: to.iso8601).fetch("suggestions")
    end

    it "lists a set made in the range with the post it targets" do
      post = create(:post, :draft, body: "teh cat sat")
      suggestion = suggest(post, edit("teh", "the"))

      expect(listed.first).to include("id" => suggestion.id, "target" => "post", "target_id" => post.id)
    end

    it "gives every edit with its status" do
      suggestion = suggest(create(:post, :draft, body: "teh cat sat"), edit("teh", "the"))
      edit_id = suggestion.edits.first.id
      suggestion_repo.reject([edit_id])
      said = { "original" => "teh", "replacement" => "the", "reason" => "typo", "status" => "rejected" }

      expect(listed.first.fetch("edits")).to eq([{ "id" => edit_id, "part" => nil, **said }])
    end

    it "names a social post as the target" do
      social_post = compose("draft", "teh one")
      suggestion_repo.replace_for_social_post(social_post.id, [edit("teh", "the", part: 1)])

      expect(listed.first).to include("target" => "social_post", "target_id" => social_post.id)
    end

    it "leaves out a set made outside the range" do
      suggest(create(:post, :draft, body: "teh cat sat"), edit("teh", "the"))

      expect(listed(from: today - 7, to: today - 1)).to be_empty
    end

    it "refuses a range that runs backwards" do
      expect(mcp_text("list_suggestions", from: today.iso8601, to: (today - 1).iso8601)).to eq("from comes after to")
    end
  end

  describe "accept_suggestion_edits" do
    it "writes every pending edit into the post" do
      post = create(:post, :draft, body: "teh cat sta")
      suggestion = suggest(post, edit("teh", "the"), edit("sta", "sat"))
      mcp_call("accept_suggestion_edits", suggestion_id: suggestion.id)

      expect(post_body(post.id)).to eq("the cat sat")
    end

    it "says which edits it took" do
      post = create(:post, :draft, body: "teh cat sat")
      suggestion = suggest(post, edit("teh", "the"))

      expect(mcp_answer("accept_suggestion_edits", suggestion_id: suggestion.id)).to eq(
        "suggestion_id" => suggestion.id, "accepted" => suggestion.edits.map(&:id), "refused" => [], "stale" => [],
      )
    end

    it "takes only the edits it names" do
      post = create(:post, :draft, body: "teh cat sta")
      suggestion = suggest(post, edit("teh", "the"), edit("sta", "sat"))
      mcp_call("accept_suggestion_edits", suggestion_id: suggestion.id, edit_ids: [suggestion.edits.first.id])

      expect(statuses(suggestion)).to eq(%w[accepted pending])
    end

    it "marks an edit stale when its text has gone" do
      post = create(:post, :draft, body: "teh cat sat")
      suggestion = suggest(post, edit("dgo", "dog"))

      expect(mcp_answer("accept_suggestion_edits", suggestion_id: suggestion.id).fetch("stale"))
        .to eq(suggestion.edits.map(&:id))
    end

    it "accepts an edit through the suggestion_id read_post gives" do
      post = create(:post, :draft, body: "teh cat sta")
      suggest(post, edit("teh", "the"), edit("sta", "sat"))
      accept_first(mcp_answer("read_post", id: post.id))

      expect(post_body(post.id)).to eq("the cat sta")
    end

    it "accepts through the suggestion_id read_social_post gives" do
      social_post = compose("draft", "teh one")
      suggestion_repo.replace_for_social_post(social_post.id, [edit("teh", "the", part: 1)])
      suggestion_id = mcp_answer("read_social_post", id: social_post.id).fetch("suggestion_id")
      mcp_call("accept_suggestion_edits", suggestion_id:)

      expect(Social::Slice["repos.social_post_repo"].by_id(social_post.id).parts.map(&:body)).to eq(["the one"])
    end

    it "writes into an unsent social post" do
      social_post = compose("draft", "teh one")
      suggestion = suggestion_repo.replace_for_social_post(social_post.id, [edit("teh", "the", part: 1)])
      mcp_call("accept_suggestion_edits", suggestion_id: suggestion.id)

      expect(Social::Slice["repos.social_post_repo"].by_id(social_post.id).parts.map(&:body)).to eq(["the one"])
    end

    describe "an edit that fits Bluesky only before its link to the site is tagged" do
      def part = "teh #{'a' * 247} https://aaronmallen.me/writing/hello"

      let(:social_post) { compose("draft", part, targets: %w[bluesky]) }
      let(:suggestion) { suggestion_repo.replace_for_social_post(social_post.id, [edit("teh", "their", part: 1)]) }

      it "is refused" do
        expect(mcp_answer("accept_suggestion_edits", suggestion_id: suggestion.id).fetch("refused"))
          .to eq(suggestion.edits.map(&:id))
      end

      it "leaves the part alone" do
        mcp_call("accept_suggestion_edits", suggestion_id: suggestion.id)

        expect(Social::Slice["repos.social_post_repo"].by_id(social_post.id).parts.map(&:body)).to eq([part])
      end
    end

    describe "edits that would leave a social post part empty" do
      let(:social_post) { compose("draft", "teh one", "teh") }
      let(:suggestion) do
        suggestion_repo.replace_for_social_post(social_post.id,
                                                [edit("teh", "the", part: 1), edit("teh", " ", part: 2)])
      end

      def bodies = Social::Slice["repos.social_post_repo"].by_id(social_post.id).parts.map(&:body)

      it "is refused" do
        expect(mcp_text("accept_suggestion_edits", suggestion_id: suggestion.id)).to eq(
          "the edits would leave part 2 of the social post under suggestion #{suggestion.id} empty; nothing changed",
        )
      end

      it "leaves every part and edit alone", :aggregate_failures do
        mcp_call("accept_suggestion_edits", suggestion_id: suggestion.id)

        expect(bodies).to eq(["teh one", "teh"])
        expect(statuses(suggestion)).to eq(%w[pending pending])
      end
    end

    it "refuses a social post already sent" do
      social_post = compose("posted", "teh one", posted_at: Time.now - 3600)
      suggestion = suggestion_repo.replace_for_social_post(social_post.id, [edit("teh", "the", part: 1)])

      expect(mcp_text("accept_suggestion_edits", suggestion_id: suggestion.id))
        .to eq("the social post under suggestion #{suggestion.id} has been sent")
    end

    it "refuses a published post" do
      post = create(:post, :published, body: "teh cat sat")
      suggestion = suggest(post, edit("teh", "the"))

      expect(mcp_text("accept_suggestion_edits", suggestion_id: suggestion.id))
        .to eq("the blog post under suggestion #{suggestion.id} is published; its edits can no longer apply")
    end

    it "leaves a published post alone", :aggregate_failures do
      post = create(:post, :published, body: "teh cat sat")
      suggestion = suggest(post, edit("teh", "the"))
      mcp_call("accept_suggestion_edits", suggestion_id: suggestion.id)

      expect(post_body(post.id)).to eq("teh cat sat")
      expect(statuses(suggestion)).to eq(%w[pending])
    end

    it "writes into a scheduled post" do
      post = create(:post, :scheduled, body: "teh cat sat")
      suggestion = suggest(post, edit("teh", "the"))
      mcp_call("accept_suggestion_edits", suggestion_id: suggestion.id)

      expect(post_body(post.id)).to eq("the cat sat")
    end

    it "refuses when no pending edit is left" do
      post = create(:post, :draft, body: "teh cat sat")
      suggestion = suggest(post, edit("teh", "the"))
      suggestion_repo.reject(suggestion.edits.map(&:id))

      expect(mcp_text("accept_suggestion_edits", suggestion_id: suggestion.id))
        .to eq("suggestion #{suggestion.id} has no pending edit with those IDs")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("accept_suggestion_edits", suggestion_id: 999_999)).to eq("no suggestion has the ID 999999")
    end
  end

  describe "reject_suggestion_edits" do
    it "rejects every open edit and leaves the post alone" do
      post = create(:post, :draft, body: "teh cat sta")
      suggestion = suggest(post, edit("teh", "the"), edit("sta", "sat"))
      mcp_call("reject_suggestion_edits", suggestion_id: suggestion.id)

      expect([statuses(suggestion), post_body(post.id)]).to eq([%w[rejected rejected], "teh cat sta"])
    end

    it "rejects only the edits it names and says which" do
      post = create(:post, :draft, body: "teh cat sta")
      suggestion = suggest(post, edit("teh", "the"), edit("sta", "sat"))
      chosen = suggestion.edits.last.id

      expect(mcp_answer("reject_suggestion_edits", suggestion_id: suggestion.id, edit_ids: [chosen]))
        .to eq("suggestion_id" => suggestion.id, "rejected" => [chosen])
    end

    it "refuses when no open edit matches" do
      post = create(:post, :draft, body: "teh cat sat")
      suggestion = suggest(post, edit("teh", "the"))

      expect(mcp_text("reject_suggestion_edits", suggestion_id: suggestion.id, edit_ids: [999_999]))
        .to eq("suggestion #{suggestion.id} has no open edit with those IDs")
    end

    it "refuses a social post already sent" do
      social_post = compose("posted", "teh one", posted_at: Time.now - 3600)
      suggestion = suggestion_repo.replace_for_social_post(social_post.id, [edit("teh", "the", part: 1)])

      expect(mcp_text("reject_suggestion_edits", suggestion_id: suggestion.id))
        .to eq("the social post under suggestion #{suggestion.id} has been sent")
    end

    it "refuses a sent social post before it looks at the edits it names" do
      social_post = compose("posted", "teh one", posted_at: Time.now - 3600)
      suggestion = suggestion_repo.replace_for_social_post(social_post.id, [edit("teh", "the", part: 1)])

      expect(mcp_text("reject_suggestion_edits", suggestion_id: suggestion.id, edit_ids: [999_999]))
        .to eq("the social post under suggestion #{suggestion.id} has been sent")
    end

    it "calls an unknown ID an error" do
      expect(mcp_text("reject_suggestion_edits", suggestion_id: 999_999)).to eq("no suggestion has the ID 999999")
    end
  end
end
