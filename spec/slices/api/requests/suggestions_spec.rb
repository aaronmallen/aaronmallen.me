# frozen_string_literal: true

RSpec.describe "API suggestions", type: :request do
  def edit(original, replacement) = { original:, replacement:, reason: "typo" }

  def post_body(id) = Posts::Slice["repos.post_queries"].by_id(id).body

  def suggest(post, *edits) = suggestion_mutations.replace_for_post(post.id, edits)

  def suggestion_mutations = Suggestions::Slice["repos.suggestion_mutations"]

  def today = Blog::TimeZone.today.iso8601

  describe "GET /api/v1/suggestions" do
    it "lists the sets made in the range with every edit, settled ones too" do
      suggestion = suggest(create(:post, :draft, body: "teh cat sat"), edit("teh", "the"))
      suggestion_mutations.reject([suggestion.edits.first.id])

      expect([call_api(:get, "/suggestions", { from: today, to: today }).dig("suggestions", 0, "edits", 0, "status"),
              status])
        .to eq(["rejected", 200])
    end

    it "answers the same JSON as list_suggestions" do
      suggest(create(:post, :draft, body: "teh cat sat"), edit("teh", "the"))

      expect(call_api(:get, "/suggestions",
                      { from: today, to: today })).to eq(trusted(mcp_answer("list_suggestions", from: today,
                                                                                                to: today)))
    end
  end

  describe "POST /api/v1/suggestions" do
    it "stores the edits as pending with a 201" do
      post = create(:post, :draft, body: "teh cat sat")
      stored = call_api(:post, "/suggestions", JSON.generate(target: "post", id: post.id, edits: [edit("teh", "the")]))

      expect([stored.except("suggestion_id"), status])
        .to eq([{ "target" => "post", "edits" => 1, "status" => "pending" }, 201])
    end

    it "refuses a published post with a 422" do
      post = create(:post, :published, body: "teh cat sat")
      found = call_api(:post, "/suggestions", JSON.generate(target: "post", id: post.id, edits: [edit("teh", "the")]))

      expect([found.fetch("message"), status])
        .to eq(["blog post #{post.id} is published; suggest edits only on a draft or scheduled post", 422])
    end

    it "refuses an empty set with a 422" do
      post = create(:post, :draft)

      expect(call_api(:post, "/suggestions", JSON.generate(target: "post", id: post.id, edits: [])).fetch("message"))
        .to eq("give at least one edit")
    end

    it "answers a post that does not exist with a 404" do
      call_api(:post, "/suggestions", JSON.generate(target: "post", id: 999_999, edits: [edit("a", "b")]))

      expect(status).to eq(404)
    end

    it "needs a token with the suggest scope" do
      body = { target: "post", id: 1, edits: [edit("a", "b")] }
      call_api(:post, "/suggestions", body, token: api_token(%w[read write]))

      expect(status).to eq(403)
    end

    describe "on a social post" do
      let(:lock_key) { "social.operations.lock_editable_social_post" }
      let(:social_post) { compose("teh cat sat") }

      def around_lock(&)
        inner = Suggestions::Slice[lock_key]
        replace_component(lock_key, ->(id) { yield(id, -> { inner.call(id) }) })
      end

      def compose(*parts)
        social_post_mutations.create_with_parts(parts:, posted_at: nil, status: "draft", targets: %w[mastodon])
      end

      def nowait(id)
        database = Suggestions::Slice["db.rom"].gateways[:default].connection
        Thread.new do
          Thread.current.report_on_exception = false
          database[:social_posts].where(id:).for_update.nowait.to_a
        end.join
        :free
      rescue Sequel::DatabaseError
        :held
      end

      def social_post_mutations = Social::Slice["repos.social_post_mutations"]

      def suggest_social
        call_api(:post, "/suggestions", { target: "social_post", id: social_post.id, edits: [edit("teh", "the")] })
      end

      before { connect_social_networks }

      it "stores an edit on the part it names" do
        two_parts = compose("the cat sat", "teh dog ran")
        body = { target: "social_post", id: two_parts.id, edits: [edit("teh", "the").merge(part: 2)] }
        call_api(:post, "/suggestions", body)

        expect(Suggestions::Slice["repos.suggestion_queries"].for_social_post(two_parts.id).edits.map(&:part))
          .to eq([2])
      end

      it "refuses an edit on a part the post lacks with a 422 naming the part", :aggregate_failures do
        two_parts = compose("the cat sat", "teh dog ran")
        body = { target: "social_post", id: two_parts.id, edits: [edit("teh", "the").merge(part: 5)] }
        found = call_api(:post, "/suggestions", body)

        expect(found.fetch("message")).to include("social post #{two_parts.id} has no part 5")
        expect(status).to eq(422)
      end

      it "refuses with a 404 and stores nothing when the post sends before the lock", :aggregate_failures do
        around_lock { |id, lock| social_post_mutations.mark_posted(id).then { lock.call } }
        suggest_social

        expect(status).to eq(404)
        expect(Suggestions::Slice["repos.suggestion_queries"].for_social_post(social_post.id)).to be_nil
      end

      it "holds the social post while it replaces the edits", :commits do
        held = []
        around_lock { |id, lock| lock.call.tap { held << nowait(id) } }
        suggest_social

        expect(held).to eq([:held])
      end
    end
  end

  describe "POST /api/v1/suggestions/:suggestion_id/accept" do
    it "answers the edits it accepted with a 200" do
      suggestion = suggest(create(:post, :draft, body: "teh cat sat"), edit("teh", "the"))
      found = call_api(:post, "/suggestions/#{suggestion.id}/accept", "{}")

      expect([found.values_at("accepted", "refused", "stale"),
              status]).to eq([[suggestion.edits.map(&:id), [], []], 200])
    end

    it "writes every pending edit into the post" do
      post = create(:post, :draft, body: "teh cat sat")
      call_api(:post, "/suggestions/#{suggest(post, edit('teh', 'the')).id}/accept", "{}")

      expect(post_body(post.id)).to eq("the cat sat")
    end

    it "answers an unknown suggestion with a 404" do
      call_api(:post, "/suggestions/999999/accept", "{}")

      expect(status).to eq(404)
    end
  end

  describe "POST /api/v1/suggestions/:suggestion_id/reject" do
    it "rejects every open edit and leaves the post alone", :aggregate_failures do
      post = create(:post, :draft, body: "teh cat sat")
      suggestion = suggest(post, edit("teh", "the"))

      expect(call_api(:post, "/suggestions/#{suggestion.id}/reject",
                      "{}").fetch("rejected")).to eq(suggestion.edits.map(&:id))
      expect(post_body(post.id)).to eq("teh cat sat")
    end

    it "refuses a set with nothing open with a 422" do
      suggestion = suggest(create(:post, :draft, body: "teh cat sat"), edit("teh", "the"))
      suggestion_mutations.reject(suggestion.edits.map(&:id))
      call_api(:post, "/suggestions/#{suggestion.id}/reject", "{}")

      expect(status).to eq(422)
    end
  end
end
