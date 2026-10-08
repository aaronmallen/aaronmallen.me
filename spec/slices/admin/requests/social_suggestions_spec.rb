# frozen_string_literal: true

RSpec.describe "Admin social suggestions", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:suggestion_mutations) { Suggestions::Slice["repos.suggestion_mutations"] }
  let(:suggestion_queries) { Suggestions::Slice["repos.suggestion_queries"] }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def accept(social_post, **params)
    post "/admin/social/#{social_post.id}/suggestions/accept", _csrf_token: admin_csrf_token, **params
  end

  def bodies(social_post) = social_post_queries.by_id(social_post.id).parts.map(&:body)

  def compose(*parts, status: "draft", posted_at: nil, targets: %w[mastodon])
    social_post_mutations.create_with_parts(parts:, posted_at:, status:, targets:)
  end

  def edits_of(social_post) = suggestion_queries.for_social_post(social_post.id).edits

  def first_edit_id(social_post) = edits_of(social_post).first.id

  def open_item(social_post) = get("/admin/social?edit=#{social_post.id}")

  def reject(social_post, **params)
    post "/admin/social/#{social_post.id}/suggestions/reject", _csrf_token: admin_csrf_token, **params
  end

  def social_post_mutations = Social::Slice["repos.social_post_mutations"]

  def social_post_queries = Social::Slice["repos.social_post_queries"]

  def statuses(social_post) = edits_of(social_post).map(&:status)

  def suggest(social_post, *edits) = suggestion_mutations.replace_for_social_post(social_post.id, edits)

  def typo(original = "teh", replacement = "the", part: 1, reason: "typo")
    { original:, replacement:, reason:, part: }
  end

  describe "signed in" do
    before do
      connect_social_networks
      sign_in_to_admin
    end

    describe "the queue count" do
      it "counts the open edits on a draft" do
        social_post = compose("teh cat sat")
        suggest(social_post, typo, typo("sat", "slept"))
        get "/admin/social?filter=drafts"

        expect(page).to have_css(".sq-suggestions", text: "2 suggestions")
      end

      it "names one edit in the singular" do
        social_post = compose("teh cat sat")
        suggest(social_post, typo)
        get "/admin/social?filter=drafts"

        expect(page).to have_css(".sq-suggestions", text: "1 suggestion")
      end

      it "counts the open edits on a queued item" do
        social_post = compose("teh cat sat", status: "scheduled", posted_at: Time.now + 3600)
        suggest(social_post, typo)
        get "/admin/social"

        expect(page).to have_css(".sq-suggestions", text: "1 suggestion")
      end

      it "shows no count when every edit is settled" do
        social_post = compose("teh cat sat")
        suggestion_mutations.reject(suggest(social_post, typo).edits.map(&:id))
        get "/admin/social?filter=drafts"

        expect(page).to have_no_css(".sq-suggestions", text: "suggestion")
      end

      it "shows no count on an item without suggestions" do
        compose("teh cat sat")
        get "/admin/social?filter=drafts"

        expect(page).to have_no_css(".sq-suggestions", text: "suggestion")
      end

      it "counts only the newest set of edits" do
        social_post = compose("teh cat sat")
        suggest(social_post, typo, typo("sat", "slept"))
        suggest(social_post, typo)
        get "/admin/social?filter=drafts"

        expect(page).to have_css(".sq-suggestions", text: "1 suggestion")
      end
    end

    describe "the card" do
      let(:social_post) { compose("teh cat sat", "teh dog ran") }

      it "shows nothing with no item open" do
        suggest(social_post, typo)
        get "/admin/social"

        expect(page).to have_no_css(".card-label", text: "Suggestions")
      end

      it "shows nothing for an item without suggestions" do
        open_item(social_post)

        expect(page).to have_no_css(".card-label", text: "Suggestions")
      end

      it "heads the card" do
        suggest(social_post, typo)
        open_item(social_post)

        expect(page).to have_css(".card-label", text: "Suggestions")
      end

      it "sits above the composer" do
        suggest(social_post, typo)
        open_item(social_post)

        expect(page).to have_css(".side-stack > form:first-child .card-label", text: "Suggestions")
      end

      it "names the part each edit belongs to" do
        suggest(social_post, typo(part: 2), typo(part: 1))
        open_item(social_post)

        expect(page.all(".sg-part").map(&:text)).to eq(["Part 1", "Part 2"])
      end

      it "names no part on a single part item" do
        single = compose("teh cat sat")
        suggest(single, typo)
        open_item(single)

        expect(page).to have_no_css(".sg-part")
      end

      it "reads the original out as the before", :aggregate_failures do
        suggest(social_post, typo, typo("sat", "slept"))
        open_item(social_post)

        expect(page.all(".sg-diff del").map(&:text)).to eq(%w[teh sat])
        expect(page.all(".sg-diff ins").map(&:text)).to eq(%w[the slept])
      end

      it "gives each edit its reason" do
        suggest(social_post, typo, typo("sat", "slept", reason: "tense"))
        open_item(social_post)

        expect(page.all(".sg-reason").map(&:text)).to eq(%w[typo tense])
      end

      it "offers Accept and Reject on each edit" do
        suggest(social_post, typo, typo("sat", "slept"))
        open_item(social_post)

        expect(page.all(".sg-actions button").map(&:text)).to eq(%w[Accept Reject Accept Reject])
      end

      it "offers Accept all and Reject all in the head" do
        suggest(social_post, typo)
        open_item(social_post)

        expect(page.all("[data-social-suggestions] .card-side button").map(&:text)).to eq(["Accept all", "Reject all"])
      end

      it "sends the acceptances to the accept endpoint" do
        suggest(social_post, typo)
        open_item(social_post)
        acceptances = page.all("[data-social-suggestions] button", text: /Accept/).map { it["formaction"] }

        expect(acceptances).to all(eq("/admin/social/#{social_post.id}/suggestions/accept"))
      end

      it "sends the rejections to the reject endpoint" do
        suggest(social_post, typo)
        open_item(social_post)
        rejections = page.all("[data-social-suggestions] button", text: /Reject/).map { it["formaction"] }

        expect(rejections).to all(eq("/admin/social/#{social_post.id}/suggestions/reject"))
      end

      it "names the edit each button decides" do
        suggest(social_post, typo)
        open_item(social_post)

        expect(page.all(".sg-actions button").map { it["value"] }).to all(eq(first_edit_id(social_post).to_s))
      end

      it "names no edit on the bulk buttons" do
        suggest(social_post, typo)
        open_item(social_post)

        expect(page.all("[data-social-suggestions] .card-side button").map { it["value"] }).to all(be_nil)
      end
    end

    describe "an edit that no longer applies" do
      let(:social_post) { compose("the cat sat") }

      before do
        suggest(social_post, typo)
        open_item(social_post)
      end

      it "marks it stale" do
        expect(page).to have_css(".sg-edit .pill", text: "stale")
      end

      it "offers only Dismiss" do
        expect(page.all(".sg-actions button").map(&:text)).to eq(%w[Dismiss])
      end

      it "refuses to accept it", :aggregate_failures do
        accept(social_post, edit_id: first_edit_id(social_post))

        expect(statuses(social_post)).to eq(%w[stale])
        expect(bodies(social_post)).to eq(["the cat sat"])
      end

      it "dismisses it" do
        reject(social_post, edit_id: first_edit_id(social_post))

        expect(statuses(social_post)).to eq(%w[rejected])
      end
    end

    describe "an edit already marked stale" do
      let(:social_post) { compose("teh cat sat") }

      before do
        suggestion = suggest(social_post, typo)
        suggestion_mutations.mark_stale(suggestion.edits.map(&:id))
      end

      it "says nothing was applied on Accept all" do
        accept(social_post)
        follow_redirect!

        expect(toast).to eq("Nothing applied · every edit went stale")
      end

      it "leaves it alone on Accept all", :aggregate_failures do
        accept(social_post)

        expect(statuses(social_post)).to eq(%w[stale])
        expect(bodies(social_post)).to eq(["teh cat sat"])
      end

      it "says nothing was applied on Accept" do
        accept(social_post, edit_id: first_edit_id(social_post))
        follow_redirect!

        expect(toast).to eq("Nothing applied · every edit went stale")
      end

      it "dismisses it on Reject all" do
        reject(social_post)

        expect(statuses(social_post)).to eq(%w[rejected])
      end

      it "clears the card on Reject all" do
        reject(social_post)
        follow_redirect!

        expect(page).to have_no_css(".card-label", text: "Suggestions")
      end
    end

    describe "accepting" do
      let(:social_post) { compose("teh cat sat", "teh dog ran") }

      it "applies one edit to its own part" do
        suggest(social_post, typo(part: 2))
        accept(social_post, edit_id: first_edit_id(social_post))

        expect(bodies(social_post)).to eq(["teh cat sat", "the dog ran"])
      end

      it "marks it accepted and leaves the rest pending" do
        suggest(social_post, typo, typo(part: 2))
        accept(social_post, edit_id: first_edit_id(social_post))

        expect(statuses(social_post)).to eq(%w[accepted pending])
      end

      it "applies every edit across every part" do
        suggest(social_post, typo, typo(part: 2))
        accept(social_post)

        expect(bodies(social_post)).to eq(["the cat sat", "the dog ran"])
      end

      it "counts them in the toast" do
        suggest(social_post, typo, typo(part: 2))
        accept(social_post)
        follow_redirect!

        expect(toast).to eq("2 suggestions applied")
      end

      it "returns to the item" do
        suggest(social_post, typo)
        accept(social_post)

        expect(last_response).to be_redirect
          .and have_attributes(location: "/admin/social?filter=queued&edit=#{social_post.id}")
      end

      it "keeps the filter it came from" do
        suggest(social_post, typo)
        accept(social_post, filter: "drafts")

        expect(last_response.headers["location"]).to eq("/admin/social?filter=drafts&edit=#{social_post.id}")
      end

      it "drops it from the card" do
        suggest(social_post, typo, typo("sat", "slept"))
        accept(social_post, edit_id: first_edit_id(social_post))
        follow_redirect!

        expect(page.all(".sg-diff del").map(&:text)).to eq(%w[sat])
      end

      it "says nothing was applied when every edit went stale" do
        suggest(social_post, typo("dog", "cat"))
        accept(social_post)
        follow_redirect!

        expect(toast).to eq("Nothing applied · every edit went stale")
      end
    end

    describe "rejecting" do
      let(:social_post) { compose("teh cat sat") }

      before { suggest(social_post, typo, typo("sat", "slept")) }

      it "marks one edit rejected and leaves the parts alone", :aggregate_failures do
        reject(social_post, edit_id: first_edit_id(social_post))

        expect(statuses(social_post)).to eq(%w[rejected pending])
        expect(bodies(social_post)).to eq(["teh cat sat"])
      end

      it "shows the rejected toast" do
        reject(social_post, edit_id: first_edit_id(social_post))
        follow_redirect!

        expect(toast).to eq("Suggestion rejected")
      end

      it "rejects every pending edit" do
        reject(social_post)

        expect(statuses(social_post)).to eq(%w[rejected rejected])
      end

      it "counts them in the toast" do
        reject(social_post)
        follow_redirect!

        expect(toast).to eq("2 suggestions rejected")
      end
    end

    describe "an edit that would pass a network limit" do
      let(:social_post) { compose("teh cat #{'a' * 492}") }

      before { suggest(social_post, typo("teh", "their")) }

      it "says which limit it would pass" do
        open_item(social_post)

        expect(page).to have_css(".sg-edit .pill", text: "Over the Mastodon limit of 500")
      end

      it "offers no Accept" do
        open_item(social_post)

        expect(page.all(".sg-actions button").map(&:text)).to eq(%w[Reject])
      end

      it "leaves the part alone", :aggregate_failures do
        accept(social_post, edit_id: first_edit_id(social_post))

        expect(bodies(social_post)).to eq(["teh cat #{'a' * 492}"])
        expect(statuses(social_post)).to eq(%w[pending])
      end

      it "says why in a toast" do
        accept(social_post, edit_id: first_edit_id(social_post))
        follow_redirect!

        expect(toast).to eq("Not applied · part 1 would pass the Mastodon limit of 500")
      end

      it "ignores a network the item does not target" do
        wider = compose("teh #{'a' * 295}", targets: %w[mastodon])
        suggest(wider, typo("teh", "their"))
        accept(wider, edit_id: first_edit_id(wider))

        expect(bodies(wider)).to eq(["their #{'a' * 295}"])
      end

      it "applies the edits that still fit" do
        suggest(social_post, typo("teh", "their"), typo("cat", "dog"))
        accept(social_post)

        expect(bodies(social_post)).to eq(["teh dog #{'a' * 492}"])
      end

      it "still lets it be rejected" do
        reject(social_post, edit_id: first_edit_id(social_post))

        expect(statuses(social_post)).to eq(%w[rejected])
      end
    end

    describe "an edit that would pass a network limit once its mentions expand" do
      let(:social_post) { compose("teh @{ada} #{'a' * 270}", targets: %w[bluesky]) }

      before do
        create(:person, :bluesky, key: "ada", bluesky_handle: "ada-lovelace.bsky.social")
        suggest(social_post, typo("teh", "their"))
      end

      it "says which limit it would pass" do
        open_item(social_post)

        expect(page).to have_css(".sg-edit .pill", text: "Over the Bluesky limit of 300")
      end

      it "leaves the part alone", :aggregate_failures do
        accept(social_post, edit_id: first_edit_id(social_post))

        expect(bodies(social_post)).to eq(["teh @{ada} #{'a' * 270}"])
        expect(statuses(social_post)).to eq(%w[pending])
      end
    end

    describe "an edit that would pass a network limit once its link to the site is tagged" do
      def part = "teh #{'a' * 247} https://aaronmallen.me/writing/hello"

      let(:social_post) { compose(part, targets: %w[bluesky]) }

      before { suggest(social_post, typo("teh", "their")) }

      it "says which limit it would pass" do
        open_item(social_post)

        expect(page).to have_css(".sg-edit .pill", text: "Over the Bluesky limit of 300")
      end

      it "leaves the part alone", :aggregate_failures do
        accept(social_post, edit_id: first_edit_id(social_post))

        expect(bodies(social_post)).to eq([part])
        expect(statuses(social_post)).to eq(%w[pending])
      end

      it "says why in a toast" do
        accept(social_post, edit_id: first_edit_id(social_post))
        follow_redirect!

        expect(toast).to eq("Not applied · part 1 would pass the Bluesky limit of 300")
      end
    end

    describe "edits that would leave a part empty" do
      let(:social_post) { compose("teh cat sat", "teh") }

      before { suggest(social_post, typo(part: 1), typo("teh", "", part: 2)) }

      it "leaves every part and edit alone", :aggregate_failures do
        accept(social_post)

        expect(bodies(social_post)).to eq(["teh cat sat", "teh"])
        expect(statuses(social_post)).to eq(%w[pending pending])
      end

      it "says why in a toast" do
        accept(social_post)
        follow_redirect!

        expect(toast).to eq("Not applied · part 2 would be left empty")
      end

      it "refuses a part left with only Unicode spaces" do
        spaced = compose("teh")
        suggest(spaced, typo("teh", "\u2003\u00a0"))
        accept(spaced)
        follow_redirect!

        expect(toast).to eq("Not applied · part 1 would be left empty")
      end
    end

    describe "a part rewritten over the limit between the read and the accept" do
      let(:social_post) { compose("the cat sat") }

      def rewrite_after_reading
        Social::Slice["repos.social_post_queries"].tap do |queries|
          allow(queries).to receive(:editable).and_wrap_original do |read, id|
            read.call(id).tap { social_post_mutations.replace_parts(id, ["teh #{'a' * 496}"]) }
          end
          replace_component("repos.social_post_queries", queries)
          replace_component("social.repos.social_post_queries", queries)
        end
      end

      before do
        suggest(social_post, typo("teh", "their"))
        rewrite_after_reading
        accept(social_post)
      end

      it "returns to the item" do
        expect(last_response.location).to include("edit=#{social_post.id}")
      end

      it "leaves the rewritten part alone", :aggregate_failures do
        expect(bodies(social_post)).to eq(["teh #{'a' * 496}"])
        expect(statuses(social_post)).to eq(%w[pending])
      end
    end

    describe "an item already posted" do
      let(:social_post) { compose("teh cat sat", status: "posted", posted_at: Time.now - 3600) }

      before { suggestion_mutations.replace_for_social_post(social_post.id, [typo]) }

      it "shows no count in the queue" do
        get "/admin/social?filter=posted"

        expect(page).to have_no_css(".sq-suggestions", text: "suggestion")
      end

      it "shows no card" do
        open_item(social_post)

        expect(page).to have_no_css(".card-label", text: "Suggestions")
      end

      it "answers 404 to an accept" do
        accept(social_post)

        expect(last_response).to be_not_found
      end

      it "answers 404 to a reject" do
        reject(social_post)

        expect(last_response).to be_not_found
      end

      it "answers 404 to a reject once every edit is settled" do
        suggestion_mutations.reject(suggestion_queries.for_social_post(social_post.id).edits.map(&:id))
        reject(social_post)

        expect(last_response).to be_not_found
      end
    end

    describe "an item mid-delivery" do
      let(:social_post) { compose("teh cat sat", status: "scheduled", posted_at: Time.now) }

      before do
        suggest(social_post, typo)
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, error: "rate limited")
      end

      it "says the item has already gone out" do
        accept(social_post)
        follow_redirect!

        expect(toast).to eq("Already posted · nothing was applied")
      end

      it "leaves the parts alone", :aggregate_failures do
        accept(social_post)

        expect(bodies(social_post)).to eq(["teh cat sat"])
        expect(statuses(social_post)).to eq(%w[pending])
      end
    end

    describe "an item sent between the lock and the save" do
      let(:social_post) { compose("teh cat sat") }

      def sends_after_reading
        inner = Social::Slice["operations.lock_editable_social_post"]

        ->(id) { inner.call(id).tap { social_post_mutations.mark_posted(id) } }
      end

      before do
        suggest(social_post, typo)
        replace_component("social.operations.lock_editable_social_post", sends_after_reading)
      end

      it "says the item has already gone out" do
        accept(social_post)
        follow_redirect!

        expect(toast).to eq("Already posted · nothing was applied")
      end

      it "leaves the parts alone", :aggregate_failures do
        accept(social_post)

        expect(bodies(social_post)).to eq(["teh cat sat"])
        expect(statuses(social_post)).to eq(%w[pending])
      end
    end

    describe "an item sent between the read and the reject" do
      let(:social_post) { compose("teh cat sat") }

      def sends_before_locking
        inner = Social::Slice["operations.lock_editable_social_post"]

        ->(id) { social_post_mutations.mark_posted(id).then { inner.call(id) } }
      end

      before do
        suggest(social_post, typo)
        replace_component("social.operations.lock_editable_social_post", sends_before_locking)
        reject(social_post)
      end

      it "answers 404" do
        expect(last_response).to be_not_found
      end

      it "leaves the edits pending" do
        expect(statuses(social_post)).to eq(%w[pending])
      end
    end

    describe "a request that goes nowhere" do
      let(:social_post) { compose("teh cat sat") }

      it "answers 404 for an item without suggestions" do
        accept(social_post)

        expect(last_response).to be_not_found
      end

      it "answers 404 for an item that doesn't exist" do
        post "/admin/social/0/suggestions/reject", _csrf_token: admin_csrf_token

        expect(last_response).to be_not_found
      end

      it "says nothing was rejected when every edit is settled" do
        suggest(social_post, typo)
        reject(social_post)
        reject(social_post)
        follow_redirect!

        expect(toast).to eq("Nothing to reject")
      end

      it "ignores an edit id from another item", :aggregate_failures do
        other = compose("teh dog ran")
        suggest(social_post, typo)
        reject(social_post, edit_id: suggest(other, typo).edits.first.id)

        expect(statuses(social_post)).to eq(%w[pending])
        expect(statuses(other)).to eq(%w[pending])
      end

      it "says nothing when an accept names an edit id from another item", :aggregate_failures do
        suggest(social_post, typo)
        accept(social_post, edit_id: suggest(compose("teh dog ran"), typo).edits.first.id)
        follow_redirect!

        expect(page).to have_no_css("[data-toast] .toast", visible: :all)
        expect(statuses(social_post)).to eq(%w[pending])
      end

      it "accepts no edit for an edit id with text after it", :aggregate_failures do
        suggest(social_post, typo)
        accept(social_post, edit_id: "#{first_edit_id(social_post)}abc")

        expect(statuses(social_post)).to eq(%w[pending])
        expect(bodies(social_post)).to eq(["teh cat sat"])
      end

      it "rejects no edit for an edit id with text after it" do
        suggest(social_post, typo)
        reject(social_post, edit_id: "#{first_edit_id(social_post)}abc")

        expect(statuses(social_post)).to eq(%w[pending])
      end

      it "rejects a request without a CSRF token", :aggregate_failures do
        suggest(social_post, typo)
        post "/admin/social/#{social_post.id}/suggestions/accept"

        expect(last_response.status).to eq(403)
        expect(statuses(social_post)).to eq(%w[pending])
      end
    end
  end

  describe "signed out" do
    %w[accept reject].each do |decision|
      it "turns away a #{decision} request" do
        post "/admin/social/1/suggestions/#{decision}"

        expect(last_response.status).to eq(403)
      end
    end
  end
end
