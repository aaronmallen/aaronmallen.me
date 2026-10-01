# frozen_string_literal: true

RSpec.describe "Admin social", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Social::Slice["repos.social_post_repo"] }

  def bodies = repo.drafts.first.parts.map(&:body)

  def compose(intent: "send", **params)
    post "/admin/social", _csrf_token: admin_csrf_token, intent:, social: { targets: %w[mastodon], **params }
  end

  def counts = page.all("[data-social-count-text]").map(&:text)

  describe "signed in with both networks connected" do
    before do
      connect_social_networks
      sign_in_to_admin
    end

    describe "the composer" do
      it "renders one empty part" do
        get "/admin/social"

        expect(page).to have_css("[data-social-part]", count: 1)
      end

      it "counts an empty part for each network" do
        get "/admin/social"

        expect(counts).to eq(["Mastodon 0/500", "Bluesky 0/300"])
      end

      it "selects every connected network" do
        get "/admin/social"

        expect(page.all("[data-social-target]").map { it[:checked] }).to all(be_truthy)
      end

      it "names both accounts and the queue in the sub-line" do
        create(:social_post, :scheduled)
        get "/admin/social"

        expect(page).to have_css(".page-head-sub", text: "Cross-posting to ruby.social and @ada.example · 1 queued")
      end

      it "counts a link the way Mastodon does" do
        compose(parts: ["https://aaronmallen.me/writing/hello there"], targets: %w[])

        expect(counts.first).to eq("Mastodon 29/500")
      end

      it "counts a mention as the handle each network gets" do
        create(:person, key: "ada", mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social",
                        bluesky_did: "did:plc:ada")
        compose(parts: ["hi @{ada}"], targets: %w[])

        expect(counts).to eq(["Mastodon 7/500", "Bluesky 19/300"])
      end

      it "ships the directory as a hidden list of people to mention" do
        create(:person, name: "Ada Lovelace", key: "ada-lovelace")
        get "/admin/social"

        expect(page).to have_css("[data-social-mentions][hidden] [role='option']", text: "Ada Lovelace", visible: :all)
      end

      it "ships no list with nobody in the directory" do
        get "/admin/social"

        expect(page).to have_no_css("[data-social-mentions]")
      end
    end

    describe "the preview" do
      def open_draft(*parts, targets: %w[mastodon bluesky])
        draft = repo.create_with_parts(parts:, targets:, status: "draft")
        get "/admin/social", filter: "drafts", edit: draft.id
      end

      def preview(network) = page.find("[data-social-preview-line='#{network}'] [data-social-preview-text]").text

      before do
        create(:person, key: "ada", name: "Ada Lovelace", mastodon_handle: "@ada@ruby.social",
                        bluesky_handle: "ada.bsky.social", bluesky_did: "did:plc:ada")
        create(:person, key: "grace", name: "Grace Hopper", mastodon_handle: "@grace@ruby.social")
      end

      it "shows each network's handle in place of a mention", :aggregate_failures do
        open_draft("hi @{ada}")

        expect(preview("mastodon")).to eq("hi @ada@ruby.social")
        expect(preview("bluesky")).to eq("hi @ada.bsky.social")
      end

      it "shows a plain name where the person has no handle" do
        open_draft("hi @{grace}")

        expect(preview("bluesky")).to eq("hi Grace Hopper")
      end

      it "previews each part on its own" do
        open_draft("hi @{ada}", "and @{grace}")

        expect(page.all("[data-social-preview-line='mastodon'] [data-social-preview-text]").map(&:text))
          .to eq(["hi @ada@ruby.social", "and @grace@ruby.social"])
      end

      it "hides the preview of a part with no mention" do
        open_draft("hello")

        expect(page).to have_css("[data-social-preview][hidden]", visible: :all)
      end

      it "hides the line of a network the post skips" do
        open_draft("hi @{ada}", targets: %w[mastodon])

        expect(page).to have_css("[data-social-preview-line='bluesky'][hidden]", visible: :all)
      end

      it "ships each network's handles for the counters" do
        get "/admin/social"

        expect(JSON.parse(page.find("[data-social-people]", visible: :all)["data-social-people"]))
          .to include("bluesky" => include("ada" => "@ada.bsky.social", "grace" => "Grace Hopper"))
      end
    end

    describe "posting now" do
      it "queues the post for delivery" do
        compose(parts: ["hello"], mode: "now")

        expect(repo.queued.first).to have_attributes(status: "scheduled", targets: %w[mastodon])
      end

      it "makes the post due right away" do
        compose(parts: ["hello"], mode: "now")

        expect(repo.due_scheduled(Time.now)).to have(1).item
      end

      it "takes a mention typed by hand" do
        create(:person, key: "ada-lovelace")
        compose(parts: ["hi @{ada-lovelace}"], mode: "now")

        expect(repo.queued.first.parts.map(&:body)).to eq(["hi @{ada-lovelace}"])
      end

      it "keeps the parts in order" do
        compose(parts: %w[one two], mode: "now")

        expect(repo.queued.first.parts.map(&:body)).to eq(%w[one two])
      end

      it "drops a blank part" do
        compose(parts: ["one", "  "], mode: "now")

        expect(repo.queued.first.parts.map(&:body)).to eq(%w[one])
      end

      it "orders the targets the way the networks are listed" do
        compose(parts: ["hello"], targets: %w[bluesky mastodon])

        expect(repo.queued.first.targets.to_a).to eq(%w[mastodon bluesky])
      end

      it "says the post is queued for its networks" do
        compose(parts: ["hello"], targets: %w[mastodon bluesky])
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Queued for Mastodon + Bluesky")
      end
    end

    describe "scheduling" do
      it "saves the post for its Chicago time" do
        compose(parts: ["hello"], mode: "schedule", schedule_at: "2027-03-01T09:30")

        expect(repo.queued.first.posted_at).to eq(Blog::TimeZone.local_time(2027, 3, 1, 9, 30))
      end

      it "says when the post goes out" do
        compose(parts: ["hello"], mode: "schedule", schedule_at: "2027-03-01T09:30")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Scheduled for Mar 1, 2027 at 09:30")
      end

      it "rejects a time it can't read" do
        compose(parts: ["hello"], mode: "schedule", schedule_at: "soon")

        expect(last_response.status).to eq(422)
      end

      it "explains a time it can't read" do
        compose(parts: ["hello"], mode: "schedule", schedule_at: "soon")

        expect(page).to have_css(".field-error", text: "Enter a date and time")
      end

      it "rejects a time the clocks skip" do
        compose(parts: ["hello"], mode: "schedule", schedule_at: "2027-03-14T02:30")

        expect(page).to have_css(".field-error", text: "the clocks skip it")
      end

      it "ignores the schedule time while posting now" do
        compose(parts: ["hello"], mode: "now", schedule_at: "soon")

        expect(repo.queued).to have(1).item
      end

      it "rejects a mode it does not know" do
        compose(parts: ["hello"], mode: "later")

        expect(last_response.status).to eq(422)
      end

      it "queues nothing for a mode it does not know" do
        compose(parts: ["hello"], mode: "later")

        expect(repo.queued).to be_empty
      end
    end

    describe "saving a draft" do
      it "saves the post as a draft" do
        compose(intent: "draft", parts: ["hello"])

        expect(repo.drafts.first).to have_attributes(status: "draft", posted_at: nil)
      end

      it "keeps the text" do
        compose(intent: "draft", parts: ["hello"])

        expect(bodies).to eq(%w[hello])
      end

      it "says the draft was saved" do
        compose(intent: "draft", parts: ["hello"])
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Draft saved")
      end

      it "saves a draft that is over a limit" do
        compose(intent: "draft", parts: ["a" * 501])

        expect(repo.drafts).to have(1).item
      end

      it "saves a draft for an intent it doesn't know" do
        compose(intent: "launch", parts: ["hello"])

        expect(repo.drafts.first).to have_attributes(status: "draft", posted_at: nil)
      end
    end

    describe "a post it won't take" do
      it "rejects an empty post" do
        compose(parts: ["   "])

        expect(last_response.status).to eq(422)
      end

      it "explains an empty post" do
        compose(parts: ["   "])

        expect(page).to have_css(".field-error", text: "Write something first")
      end

      it "keeps one empty part for a post sent with no parts" do
        compose

        expect(page.all("[data-social-body]").map(&:value)).to eq([""])
      end

      it "rejects a post with no network" do
        compose(parts: ["hello"], targets: %w[])

        expect(page).to have_css(".field-error", text: "Pick a network")
      end

      it "rejects a part over the network's limit" do
        compose(parts: ["a" * 501])

        expect(page).to have_css(".field-error", text: "over the limit")
      end

      it "marks a part over the byte limit as over in the meter" do
        compose(parts: ["👨‍👩‍👧‍👦" * 121], targets: %w[bluesky])

        expect(page).to have_css(".compose-count.over", text: "Bluesky")
      end

      it "takes a part under every selected limit" do
        compose(parts: ["a" * 301], targets: %w[mastodon])

        expect(repo.queued).to have(1).item
      end

      it "rejects a part over the limit of another selected network" do
        compose(parts: ["a" * 301], targets: %w[mastodon bluesky])

        expect(last_response.status).to eq(422)
      end

      it "rejects a part whose mention runs it over the limit once it expands" do
        create(:person, :bluesky, key: "ada", bluesky_handle: "ada-lovelace.bsky.social")
        compose(parts: ["@{ada} #{'a' * 280}"], targets: %w[bluesky])

        expect(page).to have_css(".field-error", text: "over the limit")
      end

      it "takes a part whose mention keeps it under the limit once it expands" do
        create(:person, :bluesky, key: "ada", bluesky_handle: "ada-lovelace.bsky.social")
        compose(parts: ["@{ada} #{'a' * 274}"], targets: %w[bluesky])

        expect(repo.queued).to have(1).item
      end

      it "rejects a mention of nobody in the directory" do
        compose(parts: ["hi @{nobody}"])

        expect(page).to have_css(".field-error", text: "names nobody in the directory")
      end

      it "rejects a mention of someone taken out of the directory" do
        Social::Slice["repos.person_repo"].delete(create(:person, key: "ada-lovelace").id)
        compose(parts: ["hi @{ada-lovelace}"])

        expect(repo.queued).to be_empty
      end

      it "takes a mention of someone in the directory" do
        create(:person, key: "ada-lovelace")
        compose(parts: ["hi @{ada-lovelace}"])

        expect(repo.queued.first.parts.map(&:body)).to eq(["hi @{ada-lovelace}"])
      end

      it "saves nothing when it refuses" do
        compose(parts: ["a" * 501])

        expect(repo.queued).to be_empty
      end

      it "keeps the text that was typed" do
        compose(parts: ["a" * 501])

        expect(page.all("[data-social-body]").map(&:value)).to eq(["a" * 501])
      end
    end

    describe "the queue" do
      def draft(parts: %w[a draft]) = repo.create_with_parts(parts:, targets: %w[mastodon], status: "draft")

      def engage(social_post, network, **counts)
        create(:social_post_delivery, network, social_post_id: social_post.id, **counts)
      end

      def posted(parts: %w[posted], at: Time.utc(2026, 9, 13, 2, 30), targets: %w[mastodon])
        repo.create_with_parts(parts:, targets:, status: "posted", posted_at: at)
      end

      def queued(parts: %w[waiting], at: Time.now + (90 * 60))
        repo.create_with_parts(parts:, targets: %w[mastodon], status: "scheduled", posted_at: at)
      end

      def texts = page.all(".sq-part").map(&:text)

      it "shows the queued items first" do
        queued
        draft
        get "/admin/social"

        expect(texts).to eq(%w[waiting])
      end

      it "shows only posted items under posted" do
        queued
        posted
        get "/admin/social", filter: "posted"

        expect(texts).to eq(%w[posted])
      end

      it "shows only drafts under drafts" do
        queued
        draft
        get "/admin/social", filter: "drafts"

        expect(texts).to eq(%w[a draft])
      end

      it "falls back to the queued items for a filter it doesn't know" do
        queued
        get "/admin/social", filter: "burned"

        expect(texts).to eq(%w[waiting])
      end

      it "shows a thread as one item with its parts" do
        queued(parts: %w[one two three])
        get "/admin/social"

        expect(page).to have_css("[data-social-item]", count: 1)
      end

      it "keeps the line breaks in a part" do
        queued(parts: ["one\ntwo"])
        get "/admin/social"

        expect(last_response.body).to include("one\ntwo")
      end

      it "names each network the item goes to" do
        queued
        get "/admin/social"

        expect(page).to have_css(".sq-meta .pill", text: "Mastodon")
      end

      it "counts down to an upcoming item" do
        queued
        get "/admin/social"

        expect(page).to have_css(".sq-time", text: "in 1 hour")
      end

      it "counts down in minutes to an item due soon" do
        queued(at: Time.now + (5 * 60) + 30)
        get "/admin/social"

        expect(page).to have_css(".sq-time", text: "in 5 minutes")
      end

      it "says an item due within the minute goes out in a moment" do
        queued(at: Time.now + 30)
        get "/admin/social"

        expect(page).to have_css(".sq-time", text: "in a moment")
      end

      it "dates a past item" do
        posted
        get "/admin/social", filter: "posted"

        expect(page).to have_css(".sq-time", text: "Sep 12")
      end

      it "sums engagement across the networks" do
        social_post = posted(targets: %w[mastodon bluesky])
        engage(social_post, :mastodon, like_count: 3, repost_count: 1, reply_count: 2)
        engage(social_post, :bluesky, like_count: 4, repost_count: 5, reply_count: 0)
        get "/admin/social", filter: "posted"

        expect(page.all("[data-social-engagement]").map(&:text)).to eq(%w[7 6 2])
      end

      it "reads failed for a delivery that gave up" do
        social_post = queued
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, failed: true, error: "rate limited")
        get "/admin/social"

        expect(page).to have_css(".pill.pink", text: "Mastodon failed")
      end

      it "shows the final error once the retries run out" do
        social_post = queued
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, failed: true, error: "rate limited")
        get "/admin/social"

        expect(page).to have_css(".sq-fail", text: "Mastodon: rate limited")
      end

      it "says a retry is queued while one is left" do
        social_post = queued
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, error: "rate limited")
        get "/admin/social"

        expect(page).to have_css(".sq-fail", text: "Mastodon: rate limited · retry queued")
      end

      it "shows no warning for a delivery that worked" do
        social_post = posted
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, remote_ids: %w[7])
        get "/admin/social", filter: "posted"

        expect(page).to have_no_css(".sq-fail")
      end

      it "offers Remove for a queued item" do
        queued
        get "/admin/social"

        expect(page).to have_css("[data-social-remove-item]")
      end

      it "offers Remove for a draft" do
        draft
        get "/admin/social", filter: "drafts"

        expect(page).to have_css("[data-social-remove-item]")
      end

      it "offers no Remove for a posted item" do
        posted
        get "/admin/social", filter: "posted"

        expect(page).to have_no_css("[data-social-remove-item]")
      end

      it "offers no Edit or Remove for an item awaiting its retry" do
        social_post = queued
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, error: "rate limited")
        get "/admin/social"

        expect(page).to have_no_css("[data-social-edit], [data-social-remove-item]")
      end

      it "says nothing is waiting" do
        get "/admin/social"

        expect(page).to have_css(".empty", text: "Nothing waiting")
      end
    end

    describe "paging" do
      def fill_queue
        { "third" => 3, "first" => 1, "second" => 2 }.each do |text, hours|
          make("scheduled", text, Time.now + (hours * 3600))
        end
        make("draft", "a draft")
      end

      def loaded_ids(table, &)
        counting(&).grep(/FROM "#{table}"/).flat_map { it[/IN \(([^)]*)\)/, 1].to_s.split(", ").map(&:to_i) }
      end

      def make(status, text, at = nil)
        repo.create_with_parts(parts: [text], targets: %w[mastodon], status:, posted_at: at)
      end

      def texts = page.all(".sq-part").map(&:text)

      before { lower_page_size(:admin, to: 2) }

      it "shows the ones due soonest and links to the next page", :aggregate_failures do
        fill_queue
        get "/admin/social"

        expect(texts).to eq(%w[first second])
        expect(page).to have_css("nav.pager a[rel='next'][href='/admin/social?filter=queued&page=2']")
        expect(page).to have_no_css("nav.pager a[rel='prev']")
      end

      it "keeps the oldest first order on the next page", :aggregate_failures do
        fill_queue
        get "/admin/social", filter: "queued", page: "2"

        expect(texts).to eq(%w[third])
        expect(page).to have_css("nav.pager a[rel='prev'][href='/admin/social?filter=queued']")
        expect(page).to have_no_css("nav.pager a[rel='next']")
      end

      it "counts every queued post, not one page" do
        fill_queue
        get "/admin/social", filter: "queued", page: "2"

        expect(page).to have_css(".page-head-sub", text: "3 queued")
      end

      it "loads parts and deliveries for the posts on the page only", :aggregate_failures do
        fill_queue
        on_page = repo.queued.first(2).map(&:id)

        expect(loaded_ids("social_post_parts") { get "/admin/social" }).to match_array(on_page)
        expect(loaded_ids("social_post_deliveries") { get "/admin/social" }).to match_array(on_page)
      end

      it "returns 404 for a page past the end" do
        fill_queue
        get "/admin/social", filter: "queued", page: "3"

        expect(last_response).to be_not_found
      end

      it "returns 404 for page 0, which is no page" do
        get "/admin/social", page: "0"

        expect(last_response).to be_not_found
      end

      it "pages drafts newest first", :aggregate_failures do
        %w[old middle new].each { make("draft", it) }
        get "/admin/social", filter: "drafts", page: "2"

        expect(texts).to eq(%w[old])
        expect(page).to have_css("nav.pager a[rel='prev'][href='/admin/social?filter=drafts']")
      end

      it "pages posted newest first", :aggregate_failures do
        %w[old middle new].each_with_index { |text, index| make("posted", text, Time.utc(2026, 9, 1 + index)) }
        get "/admin/social", filter: "posted"

        expect(texts).to eq(%w[new middle])
        expect(page).to have_css("nav.pager a[rel='next'][href='/admin/social?filter=posted&page=2']")
      end

      it "draws no pager when one page holds every post", :aggregate_failures do
        make("posted", "only", Time.utc(2026, 9, 1))
        get "/admin/social", filter: "posted"

        expect(texts).to eq(%w[only])
        expect(page).to have_no_css("nav.pager")
      end
    end

    describe "removing an item" do
      def item(status, posted_at: nil)
        repo.create_with_parts(parts: %w[bye], targets: %w[mastodon], status:, posted_at:)
      end

      def remove(id, filter: "queued")
        post "/admin/social/#{id}/delete", _csrf_token: admin_csrf_token, filter:
      end

      it "removes a queued item" do
        social_post = item("scheduled", posted_at: Time.now)
        remove(social_post.id)

        expect(repo.by_id(social_post.id)).to be_nil
      end

      it "removes a draft" do
        social_post = item("draft")
        remove(social_post.id, filter: "drafts")

        expect(repo.by_id(social_post.id)).to be_nil
      end

      it "goes back to the filter it was removed from" do
        social_post = item("draft")
        remove(social_post.id, filter: "drafts")

        expect(last_response.headers["Location"]).to eq("/admin/social?filter=drafts")
      end

      it "says the item was removed" do
        social_post = item("draft")
        remove(social_post.id, filter: "drafts")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Removed from queue")
      end

      it "refuses to remove a posted item" do
        social_post = item("posted", posted_at: Time.now)
        remove(social_post.id)

        expect(last_response.status).to eq(404)
      end

      it "keeps a posted item" do
        social_post = item("posted", posted_at: Time.now)
        remove(social_post.id)

        expect(repo.by_id(social_post.id)).not_to be_nil
      end

      it "sends the removal of an item mid-delivery back to the queue" do
        social_post = item("scheduled", posted_at: Time.now)
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, error: "rate limited")
        remove(social_post.id)

        expect(last_response.location).to end_with("/admin/social?filter=queued")
      end

      it "says an item mid-delivery was kept" do
        social_post = item("scheduled", posted_at: Time.now)
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, error: "rate limited")
        remove(social_post.id)
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Already posted · nothing was removed")
      end

      it "keeps an item mid-delivery and its delivery", :aggregate_failures do
        social_post = item("scheduled", posted_at: Time.now)
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, error: "rate limited")
        remove(social_post.id)

        expect(repo.by_id(social_post.id)).not_to be_nil
        expect(repo.by_id(social_post.id).deliveries.map(&:network)).to eq(%w[mastodon])
      end

      it "refuses an item that isn't there" do
        remove(0)

        expect(last_response.status).to eq(404)
      end
    end

    describe "editing an item" do
      let(:social_post) do
        repo.create_with_parts(parts: %w[first], targets: %w[mastodon], status: "draft")
      end

      def save_edit(intent: "send", **params)
        post "/admin/social/#{social_post.id}", _csrf_token: admin_csrf_token, intent:,
                                                social: { targets: %w[mastodon], **params }
      end

      def save_posted
        posted = repo.create_with_parts(parts: %w[gone], targets: %w[mastodon], status: "posted",
                                        posted_at: Time.utc(2026, 9, 13, 2, 30))
        fields = { parts: %w[new], targets: %w[mastodon], mode: "now" }
        post "/admin/social/#{posted.id}", _csrf_token: admin_csrf_token, intent: "send", social: fields
        posted
      end

      def sends_after_reading
        inner = Social::Slice["queries.editable_social_post"]

        ->(id) { inner.call(id).tap { repo.mark_posted(id) } }
      end

      it "opens the item in the composer" do
        get "/admin/social", filter: "drafts", edit: social_post.id

        expect(page.all("[data-social-body]").map(&:value)).to eq(%w[first])
      end

      it "points the composer at the item" do
        get "/admin/social", filter: "drafts", edit: social_post.id

        expect(page).to have_css("[data-social-composer][action='/admin/social/#{social_post.id}']", visible: :all)
      end

      it "prefills the send time of a queued item" do
        queued = repo.create_with_parts(parts: %w[later], targets: %w[mastodon], status: "scheduled",
                                        posted_at: Blog::TimeZone.local_time(2027, 3, 1, 9, 30))
        get "/admin/social", edit: queued.id

        expect(page.find_by_id("social-schedule_at", visible: :all).value).to eq("2027-03-01T09:30")
      end

      it "opens no item in the composer for a posted one" do
        posted = repo.create_with_parts(parts: %w[gone], targets: %w[mastodon], status: "posted", posted_at: Time.now)
        get "/admin/social", edit: posted.id

        expect(page.all("[data-social-body]").map(&:value)).to eq([""])
      end

      it "opens no item for an edit id with text after it" do
        get "/admin/social", filter: "drafts", edit: "#{social_post.id}abc"

        expect(page.all("[data-social-body]").map(&:value)).to eq([""])
      end

      it "saves back to the same item" do
        save_edit(parts: %w[second], mode: "now")

        expect(repo.by_id(social_post.id).parts.map(&:body)).to eq(%w[second])
      end

      it "adds no second item" do
        save_edit(parts: %w[second], mode: "now")

        expect(repo.queued + repo.drafts).to have(1).item
      end

      it "keeps a draft a draft for an intent it doesn't know" do
        save_edit(intent: %w[send], parts: %w[second], mode: "now")

        expect(repo.by_id(social_post.id)).to have_attributes(status: "draft", posted_at: nil)
      end

      it "keeps the item open when it refuses" do
        save_edit(parts: ["a" * 501], mode: "now")

        expect(page).to have_css("[data-social-composer][action='/admin/social/#{social_post.id}']", visible: :all)
      end

      it "explains why it refused" do
        save_edit(parts: ["a" * 501], mode: "now")

        expect(page).to have_css(".field-error", text: "over the limit")
      end

      it "sends a save of a posted item back to the queue" do
        save_posted

        expect(last_response.location).to end_with("/admin/social")
      end

      it "says a posted item has already gone out" do
        save_posted
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Already posted · nothing was saved")
      end

      it "keeps a posted item as it was" do
        posted = save_posted

        expect(repo.by_id(posted.id))
          .to have_attributes(status: "posted", posted_at: posted.posted_at, parts: [have_attributes(body: "gone")])
      end

      it "answers 404 for an item that isn't there" do
        fields = { parts: %w[new], targets: %w[mastodon], mode: "now" }
        post "/admin/social/0", _csrf_token: admin_csrf_token, intent: "send", social: fields

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for an item removed before the save" do
        repo.delete_unposted(social_post.id)
        save_edit(parts: %w[second], mode: "now")

        expect(last_response.status).to eq(404)
      end

      it "keeps an item marked posted between the read and the save" do
        replace_component("queries.editable_social_post", sends_after_reading)
        save_edit(parts: %w[second], mode: "now")

        expect(repo.by_id(social_post.id)).to have_attributes(status: "posted", parts: [have_attributes(body: "first")])
      end

      it "says the item has already gone out" do
        replace_component("queries.editable_social_post", sends_after_reading)
        save_edit(parts: %w[second], mode: "now")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Already posted")
      end
    end

    describe "editing an item mid-delivery" do
      let(:social_post) do
        repo.create_with_parts(parts: %w[first], targets: %w[mastodon], status: "scheduled", posted_at: Time.now)
      end

      before do
        create(:social_post_delivery, :mastodon, social_post_id: social_post.id, error: "rate limited")
      end

      def save_edit(intent:, **params)
        post "/admin/social/#{social_post.id}", _csrf_token: admin_csrf_token, intent:,
                                                social: { targets: %w[mastodon], parts: %w[second], **params }
      end

      it "opens no item in the composer" do
        get "/admin/social", edit: social_post.id

        expect(page.all("[data-social-body]").map(&:value)).to eq([""])
      end

      {
        "an edit" => ["send", { mode: "now" }],
        "a reschedule" => ["send", { mode: "schedule", schedule_at: "2027-03-01T09:30" }],
        "a draft" => ["draft", { mode: "now" }],
      }.each do |change, (intent, fields)|
        it "keeps the item as it was on #{change}" do
          save_edit(intent:, **fields)

          expect(repo.by_id(social_post.id))
            .to have_attributes(status: "scheduled", posted_at: social_post.posted_at,
                                parts: [have_attributes(body: "first")])
        end

        it "says so on #{change}" do
          save_edit(intent:, **fields)
          follow_redirect!

          expect(page).to have_css("[data-toast]", text: "Already posted · nothing was saved")
        end
      end
    end
  end

  describe "signed in with no network connected" do
    before do
      connect_social_networks(bluesky: {}, mastodon: {})
      sign_in_to_admin
    end

    it "disables every target" do
      get "/admin/social"

      expect(page.all("[data-social-target]").map { it[:disabled] }).to all(be_truthy)
    end

    it "selects no target" do
      get "/admin/social"

      expect(page.all("[data-social-target]").map { it[:checked] }).to all(be_falsey)
    end

    it "says no network is connected" do
      get "/admin/social"

      expect(page).to have_css(".page-head-sub", text: "No network is connected · 0 queued")
    end

    it "disables both buttons" do
      get "/admin/social"

      expect(page.all("[data-social-composer] button[type='submit']").map { it[:disabled] }).to all(be_truthy)
    end

    it "refuses a network with no credentials" do
      compose(parts: ["hello"])

      expect(page).to have_css(".field-error", text: "That network has no credentials")
    end
  end

  it "asks an unknown visitor to sign in" do
    get "/admin/social"

    expect(last_response).to be_redirect
  end
end
