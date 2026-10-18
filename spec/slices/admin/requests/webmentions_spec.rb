# frozen_string_literal: true

RSpec.describe "Admin webmentions", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:target) { create(:post, :published, slug: "hello", title: "Hello") }

  def authors = page.all(".wm-author").map(&:text)
  def filed(status, field) = Social::Slice["relations.webmentions"].with_status(status).pluck(field)
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

      it "says mentions is where you are" do
        get "/admin/webmentions"

        expect(page).to have_css(".screen-tab[aria-current='page']", exact_text: "mentions")
      end
    end

    it "shows the excerpt, the type, the target path and the time" do
      create(:webmention, :reply, post: target, excerpt: "Good one", received_at: Time.utc(2026, 9, 7, 17, 30))
      get "/admin/webmentions"

      expect(page).to have_css(".wm-excerpt", text: "Good one")
        .and have_css(".wm-kind.sand", text: "reply")
        .and have_css(".inbox-meta", text: %r{/writing/hello\s*Sep 7, 2026, 12:30})
    end

    it "puts when it arrived in a time tag" do
      create(:webmention, post: target, received_at: Time.utc(2026, 9, 7, 17, 30))
      get "/admin/webmentions"

      expect(page.find(".inbox-meta time")[:datetime]).to eq("2026-09-07T12:30:00-05:00")
    end

    { reply: "sand", like: "pink", repost: "green", mention: "blue" }.each do |type, color|
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

      describe "the trusted list" do
        let(:ada) { "https://ada.example/about" }

        def moderate(mention, action) = post "/admin/webmentions/#{mention.id}/#{action}", _csrf_token: admin_csrf_token

        def status_of(mention) = Social::Slice["relations.webmentions"].by_pk(mention.id).one[:status]

        def trusted? = webmention_queries.trusted_author?(ada)

        %i[reply mention].each do |type|
          it "adds the author of a #{type} approved by hand" do
            moderate(create(:webmention, type, post: target, author_url: ada), "approve")

            expect(trusted?).to be(true)
          end
        end

        %i[like repost].each do |type|
          it "leaves the author of a #{type} approved by hand off the list" do
            moderate(create(:webmention, type, post: target, author_url: ada), "approve")

            expect(trusted?).to be(false)
          end
        end

        it "approves the author's other pending replies and mentions on joining" do
          others = %i[reply mention].map { create(:webmention, it, post: target, author_url: ada) }
          moderate(create(:webmention, post: target, author_url: ada), "approve")

          expect(others.map { status_of(it) }).to eq(%w[approved approved])
        end

        it "leaves the author's pending likes and reposts and other authors' mentions waiting" do
          others = [*%i[like repost].map { create(:webmention, it, post: target, author_url: ada) },
                    create(:webmention, post: target)]
          moderate(create(:webmention, post: target, author_url: ada), "approve")

          expect(others.map { status_of(it) }).to eq(%w[pending pending pending])
        end

        it "leaves the author's other mentions waiting once auto-approve is off", :aggregate_failures do
          webmention_mutations.update_settings(auto_approve_known_authors: false)
          other = create(:webmention, post: target, author_url: ada)
          moderate(create(:webmention, post: target, author_url: ada), "approve")

          expect(trusted?).to be(true)
          expect(status_of(other)).to eq("pending")
        end

        it "approves nothing more for an author already on the list" do
          moderate(create(:webmention, post: target, author_url: ada), "approve")
          waiting = create(:webmention, post: target, author_url: ada)
          moderate(create(:webmention, post: target, author_url: ada), "approve")

          expect(status_of(waiting)).to eq("pending")
        end

        it "removes the author once any of their webmentions is marked spam" do
          moderate(create(:webmention, post: target, author_url: ada), "approve")
          moderate(create(:webmention, :like, post: target, author_url: ada), "spam")

          expect(trusted?).to be(false)
        end

        it "keeps the author's approved webmentions up once they are marked spam" do
          approved = create(:webmention, post: target, author_url: ada)
          moderate(approved, "approve")
          moderate(create(:webmention, post: target, author_url: ada), "spam")

          expect(status_of(approved)).to eq("approved")
        end

        it "puts the author back on a later approval" do
          moderate(create(:webmention, post: target, author_url: ada), "approve")
          moderate(create(:webmention, post: target, author_url: ada), "spam")
          moderate(create(:webmention, post: target, author_url: ada), "approve")

          expect(trusted?).to be(true)
        end

        it "keeps the author on the list when one of their webmentions is ignored" do
          moderate(create(:webmention, post: target, author_url: ada), "approve")
          moderate(create(:webmention, post: target, author_url: ada), "ignore")

          expect(trusted?).to be(true)
        end

        it "adds no one when a webmention is ignored" do
          moderate(create(:webmention, post: target, author_url: ada), "ignore")

          expect(trusted?).to be(false)
        end

        it "adds no one for an approved webmention with no author URL" do
          moderate(create(:webmention, post: target, author_url: nil), "approve")

          expect(Social::Slice["relations.trusted_authors"].count).to eq(0)
        end
      end

      it "approves a mention" do
        post "/admin/webmentions/#{mention.id}/approve", _csrf_token: admin_csrf_token

        expect(filed("approved", :id)).to eq([mention.id])
      end

      it "marks a mention as spam" do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token

        expect(filed("spam", :id)).to eq([mention.id])
      end

      it "stores the note given with spam" do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token, reason: "link farm"

        expect(filed("spam", :spam_reason)).to eq(["link farm"])
      end

      it "marks a mention as spam without a note" do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token, reason: ""

        expect(filed("spam", :spam_reason)).to eq([nil])
      end

      it "marks a mention as spam without a note when the note holds only Unicode spaces", :aggregate_failures do
        post "/admin/webmentions/#{mention.id}/spam", _csrf_token: admin_csrf_token, reason: "\u3000\u00a0"

        expect(last_response).to be_redirect
        expect(filed("spam", :spam_reason)).to eq([nil])
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

          expect(filed(status, :spam_reason)).to eq([nil])
        end
      end

      it "clears the note when marking a spam mention as spam again without one" do
        spam = create(:webmention, :spam, post: target, spam_reason: "link farm")
        post "/admin/webmentions/#{spam.id}/spam", _csrf_token: admin_csrf_token

        expect(filed("spam", :spam_reason)).to eq([nil])
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

        expect(filed("ignored", :id)).to eq([mention.id])
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

      it "posts each button to its verdict and keeps the filter", :aggregate_failures do
        mention
        get "/admin/webmentions", status: "pending"

        actions = page.all("form:has(input[name='status'][value='pending'])").map { it[:action] }

        expect(actions).to include(*%w[approve ignore spam].map { "/admin/webmentions/#{mention.id}/#{it}" })
      end

      %w[pending approved ignored delete].each do |verdict|
        it "answers 404 to the #{verdict} verdict", :aggregate_failures do
          post "/admin/webmentions/#{mention.id}/#{verdict}", _csrf_token: admin_csrf_token

          expect(last_response.status).to eq(404)
          expect(filed("pending", :id)).to eq([mention.id])
        end
      end

      it "marks Approve and Spam with icons and leaves Ignore bare" do
        create(:webmention, post: target)
        get "/admin/webmentions"
        icons = page.all(".wm-acts button").to_h { [it.text, it.first("i", minimum: 0)&.[](:class)] }

        expect(icons).to eq("Approve" => "fa-solid fa-check", "Ignore" => nil, "Spam" => "fa-solid fa-ban")
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

    describe "the inbox page head" do
      before { get "/admin/webmentions" }

      it "links to the webmentions on the socials tab" do
        expect(page).to have_link("Settings", href: "/admin/settings/socials#webmentions")
      end

      it "leaves the settings and per post cards to the settings screen", :aggregate_failures do
        expect(page).to have_no_css("#webmention-settings")
        expect(page).to have_no_css(".card-title", text: "Per post")
      end
    end

    it "sends the old settings address to its section of the socials tab" do
      get "/admin/webmentions/settings"

      expect([last_response.status, last_response.location]).to eq([302, "/admin/settings/socials#webmentions"])
    end

    it "opens its section of the socials tab from the command palette" do
      get "/admin"

      expect(page).to have_css("[data-palette-href='/admin/settings/socials#webmentions']", visible: :all)
    end

    describe "the settings screen" do
      before { get "/admin/settings/socials" }

      it "heads the page as Settings with the socials tab current", :aggregate_failures do
        expect(page).to have_css(".page-head h1", exact_text: "Settings")
        expect(page).to have_css("a.screen-tab[aria-current='page']", text: "socials")
      end

      it "sits below the people on the socials tab" do
        expect(page).to have_css("#people ~ #webmentions #webmention-settings")
      end

      it "shows the settings and per post cards", :aggregate_failures do
        expect(page).to have_css("#webmention-settings")
        expect(page).to have_css(".card-title", text: "Per post")
      end

      it "marks no inbox section current", :aggregate_failures do
        expect(page).to have_no_css("a.pill-nav-link[aria-current]")
        expect(page).to have_no_css("#command-palette-webmentions .pal-r-sub", visible: :all)
      end
    end

    describe "the settings" do
      let(:toggles) do
        {
          receive: "1",
          send_on_publish: "1",
          auto_approve_known_authors: "1",
          auto_approve_likes: "1",
          auto_approve_reposts: "1",
          enable_on_new_posts: "1",
          accept_bridgy: "1",
        }
      end

      Social::Operations::UpdateWebmentionSettings::TOGGLES.each do |name|
        it "saves #{name} turned off" do
          post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: toggles.merge(name => "0")

          expect(webmention_queries.settings.public_send(name)).to be(false)
        end

        it "shows #{name} turned off on the next request" do
          webmention_mutations.update_settings(name => false)
          get "/admin/settings/socials"

          expect(page).to have_css("input.toggle[name='settings[#{name}]']:not([checked])", visible: :all)
        end
      end

      it "draws a setting as a switch" do
        get "/admin/settings/socials"

        expect(page).to have_css("input.toggle[role='switch'][name='settings[receive]']", visible: :all)
      end

      it "leaves the toggles it isn't sent alone" do
        post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: { receive: "0" }

        expect(webmention_queries.settings).to have_attributes(receive: false, send_on_publish: true)
      end

      it "returns to its section of the socials tab" do
        post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: toggles.merge(receive: "0")

        expect(last_response.location).to end_with("/admin/settings/socials#webmentions")
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
        get "/admin/settings/socials"

        expect(page.find("textarea[name='settings[single_author_hosts]']").value)
          .to eq("ada.example\ngrace.example")
      end

      describe "a known author at a site's root" do
        def verify(source)
          stub_request(:get, source).to_return(body: <<~HTML)
            <div class="h-entry"><a class="p-author h-card" href="https://ada.example/">Ada</a>
            <a href="https://aaronmallen.me/writing/hello">read</a></div>
          HTML
          Social::Jobs::VerifyWebmention.new.perform(source, "https://aaronmallen.me/writing/hello", target.id)
          Social::Slice["relations.webmentions"].where(source_url: source).one[:status]
        end

        before do
          resolves_publicly("ada.example")
          mention = create(:webmention, post: target, author_url: "https://ada.example/")
          post "/admin/webmentions/#{mention.id}/approve", _csrf_token: admin_csrf_token
        end

        it "waits for review from a page on a host not listed" do
          expect(verify("https://ada.example/notes/1")).to eq("pending")
        end

        it "auto-approves from any page on a listed host" do
          save_hosts("ada.example")

          expect(verify("https://ada.example/notes/1")).to eq("approved")
        end

        it "says so beside the hosts" do
          get "/admin/settings/socials"

          expect(page.find("#webmention-settings .hint").text)
            .to eq(i18n.t("ui.components.webmentions.settings_card.hosts_hint"))
        end
      end

      it "names the endpoint" do
        get "/admin/settings/socials"

        expect(page).to have_css("#webmention-settings .card-side", exact_text: "Endpoint: POST /webmention")
      end
    end

    describe "the per post card" do
      it "shows a post with webmentions on" do
        create(:post, title: "On")
        get "/admin/settings/socials"

        expect(page).to have_css(".li", text: "On").and have_css(".li-side .pill.green", text: "on")
      end

      it "shows a post with webmentions off" do
        create(:post, title: "Off", webmentions_enabled: false)
        get "/admin/settings/socials"

        expect(page).to have_css(".li-side .pill.sand", text: "off")
      end

      it "links each post to its editor" do
        record = create(:post, title: "Linked")
        get "/admin/settings/socials"

        expect(page).to have_link("Linked", href: "/admin/posts/#{record.id}/edit")
      end

      it "shows an empty state without posts" do
        get "/admin/settings/socials"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.components.webmentions.posts_card.empty"))
      end

      it "lists the newest post first" do
        create(:post, :published, title: "Older", published_at: Time.utc(2026, 9, 1))
        create(:post, :published, title: "Newer", published_at: Time.utc(2026, 9, 2))
        get "/admin/settings/socials"

        expect(page.all(".li-title").map(&:text)).to eq(%w[Newer Older])
      end
    end

    describe "the trusted authors card" do
      let(:ada) { "https://ada.example/" }

      def remove(url) = post "/admin/webmentions/trusted_authors/remove", _csrf_token: admin_csrf_token, author_url: url

      def trust(url) = webmention_mutations.trust(url, approve_pending: false)

      it "lists the trusted authors, newest first" do
        trust(ada)
        Social::Slice["relations.trusted_authors"].by_pk(ada).update(created_at: Time.now - 60)
        trust("https://grace.example/")
        get "/admin/settings/socials"

        expect(page.all("#trusted-authors .li-title").map(&:text)).to eq(["https://grace.example/", ada])
      end

      it "shows an empty state without trusted authors" do
        get "/admin/settings/socials"

        empty = i18n.t("ui.components.webmentions.trusted_authors_card.empty")

        expect(page).to have_css("#trusted-authors .empty", exact_text: empty)
      end

      it "offers no field to add an author" do
        trust(ada)
        get "/admin/settings/socials"

        expect(page).to have_no_css("#trusted-authors input:not([type='hidden'])")
      end

      it "removes an author" do
        trust(ada)
        remove(ada)

        expect(webmention_queries.trusted_author?(ada)).to be(false)
      end

      it "returns to its section of the socials tab with a toast", :aggregate_failures do
        trust(ada)
        remove(ada)

        expect(last_response.location).to end_with("/admin/settings/socials#webmentions")
        expect(toast).to eq(i18n.t("webmentions_page.toasts.distrusted"))
      end

      it "keeps the author's approved webmentions approved" do
        trust(ada)
        mention = create(:webmention, :approved, post: target, author_url: ada)
        remove(ada)

        expect(filed("approved", :id)).to eq([mention.id])
      end

      it "answers an author not on the list with a 404" do
        remove(ada)

        expect(last_response.status).to eq(404)
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
