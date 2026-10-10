# frozen_string_literal: true

RSpec.describe "Admin post suggestions", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:suggestion_mutations) { Suggestions::Slice["repos.suggestion_mutations"] }
  let(:suggestion_queries) { Suggestions::Slice["repos.suggestion_queries"] }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def accept(article, **params)
    post "/admin/posts/#{article.id}/suggestions/accept", _csrf_token: admin_csrf_token, **params
  end

  def buttons = page.all("#post-suggestions .sg-actions button, #post-suggestions .dialog-foot button")

  def edits_of(article) = suggestion_queries.for_post(article.id).edits

  def first_edit_id(article) = edits_of(article).first.id

  def open_editor(article) = get("/admin/posts/#{article.id}/edit")

  def owner(button)
    return button.ancestor("form") unless button["form"]

    page.find("form[id='#{button['form']}']", visible: :all)
  end

  def post_mutations = Posts::Slice["repos.post_mutations"]

  def post_queries = Posts::Slice["repos.post_queries"]

  def reject(article, **params)
    post "/admin/posts/#{article.id}/suggestions/reject", _csrf_token: admin_csrf_token, **params
  end

  def rival_accept(article)
    accepting = Suggestions::Slice["operations.accept_suggestion_edits"]
    suggestion_id = suggest(article, typo("cat", "black cat")).id

    -> { accepting.call(suggestion_id) }
  end

  def statuses(article) = edits_of(article).map(&:status)

  def suggest(article, *edits) = suggestion_mutations.replace_for_post(article.id, edits)

  def typo(original = "teh", replacement = "the", reason: "typo") = { original:, replacement:, reason: }

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the drawer" do
      let(:article) { create(:post, :draft, body: "teh cat sat") }

      it "shows nothing on a new post" do
        get "/admin/posts/new"

        expect(page).to have_no_css("dialog#post-suggestions")
      end

      it "shows nothing for a post without suggestions" do
        open_editor(article)

        expect(page).to have_no_css("dialog#post-suggestions")
      end

      it "shows nothing once every edit is settled" do
        suggestion = suggest(article, typo)
        suggestion_mutations.reject(suggestion.edits.map(&:id))
        open_editor(article)

        expect(page).to have_no_css("dialog#post-suggestions")
      end

      it "heads the drawer" do
        suggest(article, typo)
        open_editor(article)

        expect(page).to have_css("dialog#post-suggestions[role='dialog'] .dialog-head", text: "Suggestions")
      end

      it "counts the edits in a banner" do
        suggest(article, typo, typo("sat", "slept"))
        open_editor(article)

        expect(page).to have_css(".post-banner", text: "2 suggestions")
      end

      it "opens on load when asked to" do
        suggest(article, typo)
        get "/admin/posts/#{article.id}/edit", review: "1"

        expect(page).to have_css("dialog#post-suggestions[data-dialog-show]", visible: :all)
      end

      it "stays shut without the ask" do
        suggest(article, typo)
        open_editor(article)

        expect(page).to have_no_css("dialog#post-suggestions[data-dialog-show]", visible: :all)
      end

      it "shows nothing when asked to open with every edit settled" do
        suggestion = suggest(article, typo)
        suggestion_mutations.reject(suggestion.edits.map(&:id))
        get "/admin/posts/#{article.id}/edit", review: "1"

        expect(page).to have_no_css("dialog#post-suggestions", visible: :all)
      end

      it "opens from the banner's Review button" do
        suggest(article, typo)
        open_editor(article)

        review = "button[data-dialog-open='post-suggestions'][commandfor='post-suggestions']"

        expect(page).to have_css(".post-banner #{review}", text: "Review")
      end

      it "reads the original out as the before", :aggregate_failures do
        suggest(article, typo, typo("sat", "slept"))
        open_editor(article)

        expect(page.all(".sg-diff del").map(&:text)).to eq(%w[teh sat])
        expect(page.all(".sg-diff ins").map(&:text)).to eq(%w[the slept])
      end

      it "gives each edit its reason" do
        suggest(article, typo, typo("sat", "slept", reason: "tense"))
        open_editor(article)

        expect(page.all(".sg-reason").map(&:text)).to eq(%w[typo tense])
      end

      it "offers Accept and Reject on each edit" do
        suggest(article, typo, typo("sat", "slept"))
        open_editor(article)

        expect(page.all(".sg-actions button").map(&:text)).to eq(%w[Accept Reject Accept Reject])
      end

      it "offers Accept all and Reject all in the foot" do
        suggest(article, typo)
        open_editor(article)

        expect(page.all("#post-suggestions .dialog-foot button").map(&:text)).to eq(["Accept all", "Reject all"])
      end

      it "sends the acceptances to the accept endpoint" do
        suggest(article, typo)
        open_editor(article)
        acceptances = page.all("button", text: /Accept/).map { owner(it)["action"] }

        expect(acceptances).to all(eq("/admin/posts/#{article.id}/suggestions/accept"))
      end

      it "sends the rejections to the reject endpoint" do
        suggest(article, typo)
        open_editor(article)
        rejections = page.all("button", text: /Reject/).map { owner(it)["action"] }

        expect(rejections).to all(eq("/admin/posts/#{article.id}/suggestions/reject"))
      end

      it "posts every decision" do
        suggest(article, typo)
        open_editor(article)

        expect(buttons.map { owner(it)["method"] }).to all(eq("post"))
      end

      it "keeps every decision out of the editor form" do
        suggest(article, typo)
        open_editor(article)

        expect(buttons.map { owner(it)["data-post-editor"] }).to all(be_nil)
      end

      it "sends the CSRF token with every decision" do
        suggest(article, typo)
        open_editor(article)

        expect(buttons.map { owner(it) }).to all(have_field("_csrf_token", type: "hidden", with: admin_csrf_token))
      end

      it "names the edit each button decides" do
        suggest(article, typo)
        open_editor(article)
        chosen = ["edit_id", first_edit_id(article).to_s]

        expect(page.all(".sg-actions button").map { [it["name"], it["value"]] }).to all(eq(chosen))
      end

      it "names no edit on the bulk buttons" do
        suggest(article, typo)
        open_editor(article)

        expect(page.all("#post-suggestions .dialog-foot button").map { it["value"] }).to all(be_nil)
      end
    end

    describe "a click on Accept" do
      subject(:sent) { click_accept(article) }

      let(:article) { create(:post, :draft, body: "teh cat sat") }

      def click_accept(article)
        posted = []
        browser = Capybara::Session.new(:rack_test, recorder(posted))
        browser.driver.browser.set_cookie(session_cookie, URI(Capybara.default_host))
        browser.visit("/admin/posts/#{article.id}/edit")
        browser.fill_in("Title", with: "Unsaved title")
        browser.find(".sg-actions").click_button("Accept")
        posted
      end

      def recorder(posted)
        lambda do |env|
          request = Rack::Request.new(env)
          posted << request.POST if request.post?
          Hanami.app.call(env)
        end
      end

      def session_cookie = "#{Blog::SessionCookie::KEY}=#{Spec::AdminSession.cookie(csrf_token: admin_csrf_token)}"

      before { suggest(article, typo) }

      it "sends only the edit and the CSRF token" do
        expect(sent).to eq([{ "_csrf_token" => admin_csrf_token, "edit_id" => first_edit_id(article).to_s }])
      end

      it "applies the edit" do
        expect { sent }.to change { post_queries.by_id(article.id).body }.to("the cat sat")
      end
    end

    describe "an edit that no longer applies" do
      let(:article) { create(:post, :draft, body: "the cat sat") }

      before do
        suggest(article, typo)
        open_editor(article)
      end

      it "marks it stale" do
        expect(page).to have_css(".sg-edit .pill", text: "stale")
      end

      it "offers only Dismiss" do
        expect(page.all(".sg-actions button").map(&:text)).to eq(%w[Dismiss])
      end

      it "refuses to accept it", :aggregate_failures do
        accept(article, edit_id: first_edit_id(article))

        expect(statuses(article)).to eq(%w[stale])
        expect(post_queries.by_id(article.id).body).to eq("the cat sat")
      end
    end

    describe "an edit already marked stale" do
      let(:article) { create(:post, :draft, body: "teh cat sat") }

      before do
        suggestion = suggest(article, typo)
        suggestion_mutations.mark_stale(suggestion.edits.map(&:id))
        open_editor(article)
      end

      it "still shows it as stale" do
        expect(page).to have_css(".sg-edit .pill", text: "stale")
      end

      it "offers only Dismiss" do
        expect(page.all(".sg-actions button").map(&:text)).to eq(%w[Dismiss])
      end

      it "dismisses it" do
        reject(article, edit_id: first_edit_id(article))

        expect(statuses(article)).to eq(%w[rejected])
      end

      it "dismisses it on Reject all" do
        reject(article)

        expect(statuses(article)).to eq(%w[rejected])
      end

      it "clears the drawer on Reject all" do
        reject(article)
        follow_redirect!

        expect(page).to have_no_css("dialog#post-suggestions")
      end

      it "says nothing was applied on Accept all" do
        accept(article)
        follow_redirect!

        expect(toast).to eq("Nothing applied · every edit went stale")
      end

      it "leaves it alone on Accept all", :aggregate_failures do
        accept(article)

        expect(statuses(article)).to eq(%w[stale])
        expect(post_queries.by_id(article.id).body).to eq("teh cat sat")
      end

      it "says nothing was applied on Accept" do
        accept(article, edit_id: first_edit_id(article))
        follow_redirect!

        expect(toast).to eq("Nothing applied · every edit went stale")
      end
    end

    describe "accepting one edit" do
      let(:article) { create(:post, :draft, body: "teh cat sat") }

      before { suggest(article, typo, typo("sat", "slept")) }

      it "applies it to the saved body" do
        accept(article, edit_id: first_edit_id(article))

        expect(post_queries.by_id(article.id).body).to eq("the cat sat")
      end

      it "marks it accepted and leaves the rest pending" do
        accept(article, edit_id: first_edit_id(article))

        expect(statuses(article)).to eq(%w[accepted pending])
      end

      it "returns to the editor with the drawer open" do
        accept(article, edit_id: first_edit_id(article))

        expect(last_response).to be_redirect.and have_attributes(location: "/admin/posts/#{article.id}/edit?review=1")
      end

      it "shows the applied toast" do
        accept(article, edit_id: first_edit_id(article))
        follow_redirect!

        expect(toast).to eq("Suggestion applied")
      end

      it "reflects it in the textarea" do
        accept(article, edit_id: first_edit_id(article))
        follow_redirect!

        expect(page).to have_field("Body", with: "the cat sat")
      end

      it "reflects it in the preview" do
        accept(article, edit_id: first_edit_id(article))
        follow_redirect!

        expect(page).to have_css(".preview .post-body p", exact_text: "the cat sat", visible: :all)
      end

      it "drops it from the card" do
        accept(article, edit_id: first_edit_id(article))
        follow_redirect!

        expect(page.all(".sg-diff del").map(&:text)).to eq(%w[sat])
      end
    end

    describe "accepting every edit" do
      let(:article) { create(:post, :draft, body: "teh cat sat") }

      it "returns to the editor with the drawer closed" do
        suggest(article, typo, typo("sat", "slept"))
        accept(article)

        expect(last_response).to be_redirect.and have_attributes(location: "/admin/posts/#{article.id}/edit")
      end

      it "applies them all" do
        suggest(article, typo, typo("sat", "slept"))
        accept(article)

        expect(post_queries.by_id(article.id).body).to eq("the cat slept")
      end

      it "counts them in the toast" do
        suggest(article, typo, typo("sat", "slept"))
        accept(article)
        follow_redirect!

        expect(toast).to eq("2 suggestions applied")
      end

      it "names one edit in the singular" do
        suggest(article, typo)
        accept(article)
        follow_redirect!

        expect(toast).to eq("Suggestion applied")
      end

      it "skips an edit that no longer applies", :aggregate_failures do
        suggest(article, typo, typo("dog", "cat"))
        accept(article)

        expect(post_queries.by_id(article.id).body).to eq("the cat sat")
        expect(statuses(article)).to eq(%w[accepted stale])
      end

      it "says nothing was applied when every edit went stale" do
        suggest(article, typo("dog", "cat"))
        accept(article)
        follow_redirect!

        expect(toast).to eq("Nothing applied · every edit went stale")
      end
    end

    describe "rejecting" do
      let(:article) { create(:post, :draft, body: "teh cat sat") }

      before { suggest(article, typo, typo("sat", "slept")) }

      it "marks one edit rejected and leaves the body alone", :aggregate_failures do
        reject(article, edit_id: first_edit_id(article))

        expect(statuses(article)).to eq(%w[rejected pending])
        expect(post_queries.by_id(article.id).body).to eq("teh cat sat")
      end

      it "returns to the editor with the drawer open after one" do
        reject(article, edit_id: first_edit_id(article))

        expect(last_response).to be_redirect.and have_attributes(location: "/admin/posts/#{article.id}/edit?review=1")
      end

      it "shows the rejected toast" do
        reject(article, edit_id: first_edit_id(article))
        follow_redirect!

        expect(toast).to eq("Suggestion rejected")
      end

      it "rejects every pending edit" do
        reject(article)

        expect(statuses(article)).to eq(%w[rejected rejected])
      end

      it "counts them in the toast" do
        reject(article)
        follow_redirect!

        expect(toast).to eq("2 suggestions rejected")
      end

      it "returns to the editor" do
        reject(article)

        expect(last_response).to be_redirect.and have_attributes(location: "/admin/posts/#{article.id}/edit")
      end
    end

    describe "an edit another request accepts while this Accept waits on the post" do
      let(:article) { create(:post, :draft, body: "the cat sat") }

      before do
        rival = rival_accept(article)
        inner = Suggestions::Slice["posts.operations.lock_unpublished_post"]
        replace_component("posts.operations.lock_unpublished_post", ->(id) { rival.call.then { inner.call(id) } })
      end

      it "applies it once", :aggregate_failures do
        accept(article)

        expect(post_queries.by_id(article.id).body).to eq("the black cat sat")
        expect(statuses(article)).to eq(%w[accepted])
      end

      it "counts nothing applied" do
        accept(article)
        follow_redirect!

        expect(toast).to eq("Nothing applied · every edit went stale")
      end
    end

    describe "an edit another request accepts after this Reject reads it" do
      let(:article) { create(:post, :draft, body: "the cat sat") }

      before do
        rival = rival_accept(article)
        allow(suggestion_queries).to(receive(:for_post).and_wrap_original do |read, id|
          read.call(id).tap do
            rival.call
          end
        end)
        replace_component("repos.suggestion_queries", suggestion_queries)
        replace_component("suggestions.repos.suggestion_queries", suggestion_queries)
      end

      it "leaves it accepted" do
        reject(article)

        expect(statuses(article)).to eq(%w[accepted])
      end

      it "counts nothing rejected" do
        reject(article)
        follow_redirect!

        expect(toast).to eq("Nothing to reject")
      end
    end

    describe "a published post" do
      let(:article) { create(:post, :published, body: "teh cat sat") }

      before { suggest(article, typo) }

      it "hides the drawer" do
        open_editor(article)

        expect(page).to have_no_css("dialog#post-suggestions")
      end

      it "offers no decision" do
        open_editor(article)

        expect(page).to have_no_css("form[action^='/admin/posts/#{article.id}/suggestions']", visible: :all)
      end

      it "keeps the edit note box under the body" do
        open_editor(article)

        expect(page).to have_css(".editor-main > [data-markdown-editor]:has(#post-body[data-post-body]) + .card")
      end

      it "keeps the edit note dialog" do
        open_editor(article)

        expect(page).to have_css("form[data-post-editor] dialog[data-edit-note-dialog]", visible: :all)
      end

      it "refuses to accept an edit", :aggregate_failures do
        accept(article, edit_id: first_edit_id(article))

        expect(statuses(article)).to eq(%w[pending])
        expect(post_queries.by_id(article.id).body).to eq("teh cat sat")
      end

      it "refuses Accept all", :aggregate_failures do
        accept(article)

        expect(statuses(article)).to eq(%w[pending])
        expect(post_queries.by_id(article.id).body).to eq("teh cat sat")
      end

      it "says why nothing was applied" do
        accept(article)
        follow_redirect!

        expect(toast).to eq("Not applied · the post is published")
      end

      it "returns to the editor" do
        accept(article)

        expect(last_response).to be_redirect.and have_attributes(location: "/admin/posts/#{article.id}/edit")
      end
    end

    describe "a post that publishes while this Accept waits on it" do
      let(:article) { create(:post, :scheduled, body: "teh cat sat") }

      before do
        suggest(article, typo)
        inner = Suggestions::Slice["posts.operations.lock_unpublished_post"]
        publishing = ->(id) { post_mutations.publish(id, at: Time.now).then { inner.call(id) } }
        replace_component("posts.operations.lock_unpublished_post", publishing)
      end

      it "leaves the body alone", :aggregate_failures do
        accept(article)

        expect(statuses(article)).to eq(%w[pending])
        expect(post_queries.by_id(article.id).body).to eq("teh cat sat")
      end
    end

    describe "a scheduled post" do
      let(:article) { create(:post, :scheduled, body: "teh cat sat") }

      before { suggest(article, typo) }

      it "shows the drawer" do
        open_editor(article)

        expect(page).to have_css("dialog#post-suggestions")
      end

      it "applies an edit" do
        accept(article, edit_id: first_edit_id(article))

        expect(post_queries.by_id(article.id).body).to eq("the cat sat")
      end
    end

    describe "a request that goes nowhere" do
      let(:article) { create(:post, :draft, body: "teh cat sat") }

      it "answers 404 for a post without suggestions" do
        accept(article)

        expect(last_response).to be_not_found
      end

      it "answers 404 for a post that doesn't exist" do
        post "/admin/posts/0/suggestions/reject", _csrf_token: admin_csrf_token

        expect(last_response).to be_not_found
      end

      it "leaves an edit that was settled already alone", :aggregate_failures do
        suggest(article, typo)
        accept(article)
        accept(article)

        expect(last_response).to be_redirect
        expect(statuses(article)).to eq(%w[accepted])
      end

      it "says nothing was rejected when every edit is settled" do
        suggest(article, typo)
        reject(article)
        reject(article)
        follow_redirect!

        expect(toast).to eq("Nothing to reject")
      end

      it "ignores an edit id from another post", :aggregate_failures do
        other = create(:post, :draft, body: "teh dog ran")
        suggest(article, typo)
        reject(article, edit_id: suggest(other, typo).edits.first.id)

        expect(statuses(article)).to eq(%w[pending])
        expect(statuses(other)).to eq(%w[pending])
      end

      it "shrugs off an edit id that isn't a number", :aggregate_failures do
        suggest(article, typo)
        accept(article, edit_id: %w[1])

        expect(last_response).to be_redirect
        expect(statuses(article)).to eq(%w[pending])
      end

      it "accepts no edit for an edit id with text after it", :aggregate_failures do
        suggest(article, typo)
        accept(article, edit_id: "#{first_edit_id(article)}abc")

        expect(statuses(article)).to eq(%w[pending])
        expect(post_queries.by_id(article.id).body).to eq("teh cat sat")
      end

      it "rejects no edit for an edit id with text after it" do
        suggest(article, typo)
        reject(article, edit_id: "#{first_edit_id(article)}abc")

        expect(statuses(article)).to eq(%w[pending])
      end

      it "rejects a request without a CSRF token", :aggregate_failures do
        suggest(article, typo)
        post "/admin/posts/#{article.id}/suggestions/accept"

        expect(last_response.status).to eq(403)
        expect(statuses(article)).to eq(%w[pending])
      end
    end
  end

  describe "signed out" do
    %w[accept reject].each do |decision|
      it "turns away a #{decision} request" do
        post "/admin/posts/1/suggestions/#{decision}"

        expect(last_response.status).to eq(403)
      end
    end
  end
end
