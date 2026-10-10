# frozen_string_literal: true

RSpec.describe "Admin webmentions", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:target) { create(:post, :published, slug: "hello", title: "Hello") }

  def authors = page.all(".wm-author").map(&:text)
  def webmention_mutations = Social::Slice["repos.webmention_mutations"]

  def webmention_queries = Social::Slice["repos.webmention_queries"]

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

        expect(page).to have_css(".wm-author[target='_blank'][rel='noopener noreferrer']", text: "Ada")
      end

      it "marks the kind of mention with an icon" do
        get "/admin/webmentions"

        expect(page).to have_css(".wm-kind i[aria-hidden='true']")
      end

      it "says webmentions is where you are" do
        get "/admin/webmentions"

        expect(page).to have_css(".screen-tab[aria-current='page']", text: "webmentions")
      end
    end

    it "shows the excerpt, the type, the target path and the time" do
      create(:webmention, :reply, post: target, excerpt: "Good one", received_at: Time.utc(2026, 9, 7, 17, 30))
      get "/admin/webmentions"

      expect(page).to have_css(".wm-excerpt", text: "Good one")
        .and have_css(".wm-kind.pink", text: "reply")
        .and have_css(".inbox-meta", text: %r{/writing/hello\s*Sep 7, 2026, 12:30})
    end

    it "puts when it arrived in a time tag" do
      create(:webmention, post: target, received_at: Time.utc(2026, 9, 7, 17, 30))
      get "/admin/webmentions"

      expect(page.find(".inbox-meta time")[:datetime]).to eq("2026-09-07T12:30:00-05:00")
    end

    { reply: "pink", like: "sand", repost: "green", mention: "blue" }.each do |type, color|
      it "colors the #{type} label #{color}" do
        create(:webmention, type, post: target)
        get "/admin/webmentions"

        expect(page).to have_css(".wm-kind.#{color}", text: type.to_s)
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

    it "shows an empty inbox for the approved filter with no approved mentions" do
      get "/admin/webmentions", status: "approved"

      expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.webmentions.index.empty.approved"))
    end

    describe "with a seen pending mention" do
      let!(:seen) do
        create(:webmention, post: target, author_name: "Seen", seen_at: Time.now)
      end

      before { get "/admin/webmentions" }

      it "lists and counts it with the pending mentions", :aggregate_failures do
        expect(authors).to eq(%w[Seen])
        expect(page).to have_css(".page-head-sub", exact_text: "1 pending · 0 shown on the site")
      end

      it "keeps its approve, ignore and spam buttons" do
        actions = page.all("form").map { it[:action] }

        expect(actions).to include(*%w[approve ignore spam].map { "/admin/webmentions/#{seen.id}/#{it}" })
      end
    end

    describe "moderating" do
      let(:mention) { create(:webmention, post: target) }

      it "approves a mention" do
        post "/admin/webmentions/#{mention.id}/approve", _csrf_token: admin_csrf_token

        expect(webmention_queries.by_status("approved").map(&:id)).to eq([mention.id])
      end

      it "marks a mention as spam" do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token

        expect(webmention_queries.by_status("spam").map(&:id)).to eq([mention.id])
      end

      it "stores the note given with spam" do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token, reason: "link farm"

        expect(webmention_queries.by_status("spam").map(&:spam_reason)).to eq(["link farm"])
      end

      it "marks a mention as spam without a note" do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token, reason: ""

        expect(webmention_queries.by_status("spam").map(&:spam_reason)).to eq([nil])
      end

      it "marks a mention as spam without a note when the note holds only Unicode spaces", :aggregate_failures do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token, reason: "\u3000\u00a0"

        expect(last_response).to be_redirect
        expect(webmention_queries.by_status("spam").map(&:spam_reason)).to eq([nil])
      end

      %w[approve ignore].each do |action|
        it "keeps no note given with #{action}" do
          post "/admin/webmentions/#{mention.id}/#{action}", _csrf_token: admin_csrf_token, reason: "link farm"

          expect(Social::Slice["relations.webmentions"].by_pk(mention.id).one[:spam_reason]).to be_nil
        end
      end

      { "approve" => "approved", "ignore" => "ignored" }.each do |action, status|
        it "clears the note when #{action.chomp('e')}ing a spam mention" do
          spam = create(:webmention, :spam, post: target, spam_reason: "link farm")
          post "/admin/webmentions/#{spam.id}/#{action}", _csrf_token: admin_csrf_token

          expect(webmention_queries.by_status(status).map(&:spam_reason)).to eq([nil])
        end
      end

      it "clears the note when marking a spam mention as spam again without one" do
        spam = create(:webmention, :spam, post: target, spam_reason: "link farm")
        post "/admin/webmentions/#{spam.id}/spam", _csrf_token: admin_csrf_token

        expect(webmention_queries.by_status("spam").map(&:spam_reason)).to eq([nil])
      end

      it "offers a note field beside Spam" do
        mention
        get "/admin/webmentions"

        expect(page).to have_css("form.wm-spam input.inp[name='reason'][placeholder='Why spam? (optional)']")
      end

      it "shows the note on a spam mention" do
        create(:webmention, :spam, post: target, spam_reason: "link farm")
        get "/admin/webmentions", status: "spam"

        expect(page).to have_css(".wm-reason", exact_text: "Spam: link farm")
      end

      it "ignores a mention" do
        post "/admin/webmentions/#{mention.id}/ignore", _csrf_token: admin_csrf_token

        expect(webmention_queries.by_status("ignored").map(&:id)).to eq([mention.id])
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

      it "offers every button on a pending mention", :aggregate_failures do
        mention
        get "/admin/webmentions"

        expect(page).to have_button("Approve")
        expect(page).to have_button("Spam")
        expect(page).to have_button("Ignore")
      end

      it "posts each button to its verdict", :aggregate_failures do
        mention
        get "/admin/webmentions"

        %w[approve ignore spam].each do |verdict|
          expect(page).to have_css("form[action='/admin/webmentions/#{mention.id}/#{verdict}']")
        end
      end

      %w[pending approved ignored delete].each do |verdict|
        it "answers 404 to the #{verdict} verdict", :aggregate_failures do
          post "/admin/webmentions/#{mention.id}/#{verdict}", _csrf_token: admin_csrf_token

          expect(last_response.status).to eq(404)
          expect(webmention_queries.by_status("pending").map(&:id)).to eq([mention.id])
        end
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

          expect(webmention_queries.settings.public_send(name)).to be(false)
        end

        it "shows #{name} turned off on the next request" do
          webmention_mutations.update_settings(name => false)
          get "/admin/webmentions"

          expect(page).to have_css("input.toggle[name='settings[#{name}]']:not([checked])", visible: :all)
        end
      end

      it "draws a setting as a switch" do
        get "/admin/webmentions"

        expect(page).to have_css("input.toggle[role='switch'][name='settings[receive]']", visible: :all)
      end

      it "leaves the toggles it isn't sent alone" do
        post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: { receive: "0" }

        expect(webmention_queries.settings).to have_attributes(receive: false, send_on_publish: true)
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

      def save_hosts(text)
        post "/admin/webmentions/settings", _csrf_token: admin_csrf_token,
                                            settings: toggles.merge(single_author_hosts: text)
      end

      it "saves one person's sites from the hosts it is sent, one per line, cleaned up and in order" do
        save_hosts("grace.example\r\nhttps://Ada.Example/about\n\nnot a host/\n")

        expect(webmention_queries.settings.single_author_hosts).to eq(%w[ada.example grace.example])
      end

      it "clears the hosts when sent none" do
        webmention_mutations.update_settings(single_author_hosts: ["ada.example"])
        save_hosts("")

        expect(webmention_queries.settings.single_author_hosts).to eq([])
      end

      it "leaves the hosts alone when the form leaves them out" do
        webmention_mutations.update_settings(single_author_hosts: ["ada.example"])
        post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: { receive: "0" }

        expect(webmention_queries.settings.single_author_hosts).to eq(["ada.example"])
      end

      it "says nothing changed when the hosts match the stored ones" do
        webmention_mutations.update_settings(single_author_hosts: ["ada.example"])
        save_hosts("ada.example")
        follow_redirect!

        expect(page).to have_css("[data-toast]", exact_text: "Nothing saved · no setting changed")
      end

      it "shows the stored hosts, one per line" do
        webmention_mutations.update_settings(single_author_hosts: %w[ada.example grace.example])
        get "/admin/webmentions"

        expect(page.find("textarea[name='settings[single_author_hosts]']").value)
          .to eq("ada.example\ngrace.example")
      end

      it "names the endpoint" do
        get "/admin/webmentions"

        expect(page).to have_css("#webmention-settings .card-side", exact_text: "Endpoint: POST /webmention")
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

      it "lists the newest post first" do
        create(:post, :published, title: "Older", published_at: Time.utc(2026, 9, 1))
        create(:post, :published, title: "Newer", published_at: Time.utc(2026, 9, 2))
        get "/admin/webmentions"

        expect(page.all(".li-title").map(&:text)).to eq(%w[Newer Older])
      end
    end

    describe "loading posts" do
      before do
        create(:webmention, post: target)
        create(:post, title: "Quiet")
      end

      it "reads no post bodies" do
        statements = counting { get "/admin/webmentions" }

        expect(statements.grep(/"body"/)).to be_empty
      end

      it "reads no post tags" do
        statements = counting { get "/admin/webmentions" }

        expect(statements.grep(/FROM "post_tags"|FROM "tags"/)).to be_empty
      end

      it "reads the posts once" do
        statements = counting { get "/admin/webmentions" }

        expect(statements.grep(/FROM "posts"/)).to have(1).item
      end
    end

    describe "the palette row" do
      it "leaves the pending count to Inbox" do
        2.times { create(:webmention, post: target) }
        get "/admin"

        expect(page).to have_no_css("#command-palette-webmentions .pal-r-sub", visible: :all)
      end
    end
  end
end
