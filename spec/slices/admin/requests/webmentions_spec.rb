# frozen_string_literal: true

RSpec.describe "Admin webmentions", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Social::Slice["repos.webmention_repo"] }
  let(:target) { create(:post, :published, slug: "hello", title: "Hello") }

  def authors = page.all(".wm-author .li-title").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "paging" do
      before do
        lower_page_size(:admin, to: 2)
        %w[Ada Grace Alan].each_with_index do |author_name, index|
          create(:webmention, :approved, post: target, author_name:, received_at: Time.utc(2026, 9, 1 + index))
        end
        create(:webmention, post: target, author_name: "Barbara")
      end

      it "shows the newest page and links to older mentions", :aggregate_failures do
        get "/admin/webmentions", status: "approved"

        expect(authors).to eq(%w[Alan Grace])
        older = "/admin/webmentions?status=approved&page=2"
        expect(page).to have_css("nav.pager a[rel='next'][href='#{older}']", text: "Older")
      end

      it "keeps the filter on a later page", :aggregate_failures do
        get "/admin/webmentions", status: "approved", page: "2"

        expect(authors).to eq(%w[Ada])
        expect(page).to have_css("nav.pager a[rel='prev'][href='/admin/webmentions?status=approved']", text: "Newer")
        expect(page).to have_css(".seg input[value='approved'][checked]")
      end

      it "counts from every mention, not the page" do
        get "/admin/webmentions", status: "approved"

        expect(page).to have_css(".page-head-sub", exact_text: "1 pending · 3 shown on the site")
      end

      it "draws no pager when one page holds every mention" do
        get "/admin/webmentions"

        expect(page).to have_no_css("nav.pager")
      end

      it "returns 404 for a page past the end" do
        get "/admin/webmentions", status: "approved", page: "3"

        expect(last_response).to be_not_found
      end
    end

    describe "the inbox" do
      before do
        create(:webmention, :reply, post: target, author_name: "Ada")
        create(:webmention, :approved, post: target, author_name: "Grace")
        create(:webmention, :spam, post: target, author_name: "Alan")
        create(:webmention, :ignored, post: target, author_name: "Barbara")
      end

      { "pending" => "Ada", "approved" => "Grace", "spam" => "Alan", "ignored" => "Barbara" }.each do |status, author|
        it "shows only #{status} mentions with the #{status} filter" do
          get "/admin/webmentions", status: status

          expect(authors).to eq([author])
        end

        it "checks the #{status} filter" do
          get "/admin/webmentions", status: status

          expect(page).to have_css(".seg input[name='status'][value='#{status}'][checked]")
        end
      end

      it "puts the ignored filter before spam" do
        get "/admin/webmentions"

        expect(page.all(".seg input[name='status']", visible: :all).map(&:value))
          .to eq(%w[pending approved ignored spam])
      end

      it "shows pending mentions without a filter" do
        get "/admin/webmentions"

        expect(authors).to eq(%w[Ada])
      end

      it "shows pending mentions for a filter it doesn't know" do
        get "/admin/webmentions", status: "junk"

        expect(authors).to eq(%w[Ada])
      end

      it "counts the pending mentions and the ones shown on the site" do
        get "/admin/webmentions"

        expect(page).to have_css(".page-head-sub", exact_text: "1 pending · 1 shown on the site")
      end

      it "counts from every mention while filtered" do
        get "/admin/webmentions", status: "spam"

        expect(page).to have_css(".page-head-sub", exact_text: "1 pending · 1 shown on the site")
      end

      it "links the author to the source in a new tab" do
        get "/admin/webmentions"

        expect(page).to have_css(".wm-author a[target='_blank'][rel='noopener noreferrer']", text: "Ada")
      end

      it "says webmentions is where you are" do
        get "/admin/webmentions"

        expect(page).to have_css(".ctx-where", text: %r{Inbox\s+/\s+webmentions})
      end
    end

    it "shows the excerpt, the type pill, the target path and the time" do
      create(:webmention, :reply, post: target, excerpt: "Good one", received_at: Time.utc(2026, 9, 7, 17, 30))
      get "/admin/webmentions"

      expect(page).to have_css(".wm-excerpt", text: "Good one")
        .and have_css(".wm-meta .pill.pink", text: "reply")
        .and have_css(".wm-meta", text: "/writing/hello · Sep 7, 2026, 12:30")
    end

    { reply: "pink", like: "sand", repost: "green", mention: "blue" }.each do |type, color|
      it "colors the #{type} pill #{color}" do
        create(:webmention, type, post: target)
        get "/admin/webmentions"

        expect(page).to have_css(".wm-meta .pill.#{color}", text: type.to_s)
      end
    end

    it "says a like carries no content" do
      create(:webmention, :like, post: target)
      get "/admin/webmentions"

      expect(page).to have_css(".wm-excerpt.quiet", text: "no content · like only")
    end

    it "shows an empty inbox for a filter with no mentions" do
      get "/admin/webmentions"

      expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.webmentions.index.empty.pending"))
    end

    it "shows an empty inbox for the ignored filter with no ignored mentions" do
      create(:webmention, :spam, post: target)
      get "/admin/webmentions", status: "ignored"

      expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.webmentions.index.empty.ignored"))
    end

    describe "moderating" do
      let(:mention) { create(:webmention, post: target) }

      it "approves a mention" do
        post "/admin/webmentions/#{mention.id}/approve", _csrf_token: admin_csrf_token

        expect(repo.by_status("approved").map(&:id)).to eq([mention.id])
      end

      it "marks a mention as spam" do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token

        expect(repo.by_status("spam").map(&:id)).to eq([mention.id])
      end

      it "ignores a mention" do
        post "/admin/webmentions/#{mention.id}/ignore", _csrf_token: admin_csrf_token

        expect(repo.by_status("ignored").map(&:id)).to eq([mention.id])
      end

      it "keeps the filter on the way back" do
        post "/admin/webmentions/#{mention.id}/approve", _csrf_token: admin_csrf_token, status: "spam"

        expect(last_response).to be_redirect
          .and have_attributes(location: end_with("/admin/webmentions?status=spam"))
      end

      it "shows the approved toast" do
        post "/admin/webmentions/#{mention.id}/approve", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Approved · now visible on the post")
      end

      it "shows the spam toast" do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Marked as spam")
      end

      it "shows the ignored toast" do
        post "/admin/webmentions/#{mention.id}/ignore", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Ignored · hidden from the post")
      end

      %w[approve spam ignore].each do |verdict|
        it "answers 404 when asked to #{verdict} a mention that isn't there" do
          post "/admin/webmentions/0/#{verdict}", _csrf_token: admin_csrf_token

          expect(last_response.status).to eq(404)
        end
      end

      it "offers every button on a pending mention", :aggregate_failures do
        mention
        get "/admin/webmentions"

        expect(page).to have_button("Approve")
        expect(page).to have_button("Spam")
        expect(page).to have_button("Ignore")
      end

      it "hides Approve on an approved mention", :aggregate_failures do
        create(:webmention, :approved, post: target)
        get "/admin/webmentions", status: "approved"

        expect(page).to have_no_button("Approve")
        expect(page).to have_button("Spam")
        expect(page).to have_button("Ignore")
      end

      it "hides Spam on a mention already marked as spam", :aggregate_failures do
        create(:webmention, :spam, post: target)
        get "/admin/webmentions", status: "spam"

        expect(page).to have_button("Approve")
        expect(page).to have_no_button("Spam")
        expect(page).to have_button("Ignore")
      end

      it "hides Ignore on an ignored mention", :aggregate_failures do
        create(:webmention, :ignored, post: target)
        get "/admin/webmentions", status: "ignored"

        expect(page).to have_button("Approve")
        expect(page).to have_button("Spam")
        expect(page).to have_no_button("Ignore")
      end
    end

    describe "the settings" do
      let(:toggles) do
        {
          receive: "1",
          send_on_publish: "1",
          auto_approve_known_authors: "1",
          enable_on_new_posts: "1",
          accept_bridgy: "1",
        }
      end

      Admin::Actions::Webmentions::UpdateSettings::SETTINGS.each do |name|
        it "saves #{name} turned off" do
          post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: toggles.merge(name => "0")

          expect(repo.settings.public_send(name)).to be(false)
        end

        it "shows #{name} turned off on the next request" do
          repo.update_settings(name => false)
          get "/admin/webmentions"

          expect(page).to have_css("input.toggle[name='settings[#{name}]']:not([checked])", visible: :all)
        end
      end

      it "leaves the toggles it isn't sent alone" do
        post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: { receive: "0" }

        expect(repo.settings).to have_attributes(receive: false, send_on_publish: true)
      end

      it "shows the saved toast" do
        post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: toggles.merge(receive: "0")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Settings saved")
      end

      it "says nothing changed when the form matches the stored settings" do
        post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: toggles
        follow_redirect!

        expect(page).to have_css("[data-toast]", exact_text: "Nothing saved · no setting changed")
      end

      it "names the endpoint" do
        get "/admin/webmentions"

        expect(page).to have_css(".hint", text: "Endpoint: POST /webmention")
      end
    end

    describe "the per post card" do
      it "shows a post with webmentions on" do
        create(:post, title: "On")
        get "/admin/webmentions"

        expect(page).to have_css(".li", text: "On").and have_css(".li-side .pill.green", text: "on")
      end

      it "shows a post with webmentions off" do
        create(:post, title: "Off", webmentions_enabled: false)
        get "/admin/webmentions"

        expect(page).to have_css(".li-side .pill.sand", text: "off")
      end

      it "links each post to its editor" do
        record = create(:post, title: "Linked")
        get "/admin/webmentions"

        expect(page).to have_link("Linked", href: "/admin/posts/#{record.id}/edit")
      end

      it "shows an empty state without posts" do
        get "/admin/webmentions"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.components.webmentions.posts_card.empty"))
      end
    end

    describe "the palette row" do
      it "shows the pending count" do
        2.times { create(:webmention, post: target) }
        get "/admin"

        expect(page).to have_css("#command-palette-webmentions .pal-r-sub.warn", text: "2 waiting", visible: :all)
      end

      it "says nothing at zero" do
        create(:webmention, :approved, post: target)
        get "/admin"

        expect(page).to have_no_css("#command-palette-webmentions .pal-r-sub", visible: :all)
      end
    end
  end

  it "redirects to sign-in when signed out" do
    get "/admin/webmentions"

    expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
  end
end
