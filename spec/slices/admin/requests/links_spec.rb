# frozen_string_literal: true

RSpec.describe "Admin links", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }

  def again_hint = i18n.t("ui.views.links.index.again", link: "shares.localhost/talk")

  def error(key) = i18n.t(key, scope: "ui.components.links.field_error")

  def json = JSON.parse(last_response.body)

  def link(destination = "https://example.com/talk", at: Time.now, clicks: 0, **)
    Shares::Slice["operations.create_short_link"].call({ destination:, ** }).value!.tap do |made|
      relation.by_pk(made.id).update(created_at: at, click_count: clicks)
    end
  end

  def links = relation.with_code.to_a

  def page = Capybara.string(last_response.body)

  def relation = Shares::Slice["relations.short_links"]

  def shorten(accept: "text/html", **fields)
    post "/admin/links", { link: fields }, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token, "HTTP_ACCEPT" => accept }
  end

  def titles = page.all(".link-row-title").map(&:text)

  before { sign_in_to_admin }

  it "lists the tab under Publish beside Files" do
    get "/admin/links"

    expect(page.all(".screen-tabs a.screen-tab").map { it[:href] })
      .to eq(%w[/admin/posts /admin/social /admin/files /admin/links])
  end

  it "says when nothing is shortened yet" do
    get "/admin/links"

    expect(page).to have_css(".empty", text: i18n.t("ui.views.links.index.empty"))
  end

  describe "a row" do
    let!(:made) { link("https://www.example.com/talk", code: "talk", at: Time.utc(2026, 9, 3, 12), clicks: 1_204) }

    let(:row) { page.find(".link-row") }

    it "shows the host when the link has no title, the destination, clicks and the date", :aggregate_failures do
      get "/admin/links"

      expect(row).to have_css(".link-row-title", exact_text: "example.com")
      expect(row).to have_css(".link-row-url[title='https://www.example.com/talk']", exact_text: "example.com/talk")
      expect(row.find(".link-row-meta").text).to include("1,204 clicks", "made Sep 3, 2026")
      expect(row.find(".link-row-meta").text).not_to include("retargeted")
    end

    it "shows the title and when I last pointed it somewhere new", :aggregate_failures do
      Shares::Slice["operations.set_short_link_title"].call(made.id, { title: "My talk" })
      Shares::Slice["operations.retarget_short_link"].call(made.id, { destination: "https://example.com/v2" })
      get "/admin/links"

      expect(row).to have_css(".link-row-title", exact_text: "My talk")
      expect(row.find(".link-row-meta").text).to include("retargeted")
    end

    it "copies the share host link and opens the destination", :aggregate_failures do
      get "/admin/links"

      expect(row).to have_css("button.link-chip[data-record-key='http://shares.localhost/talk']",
                              text: "shares.localhost/talk")
      expect(row).to have_css("a[href='https://www.example.com/talk'][target='_blank'][rel='noopener']")
    end

    it "sums the links and clicks in the lede" do
      get "/admin/links"

      expect(page.find(".page-head-sub").text).to start_with("1 short link on shares.localhost, 1,204 clicks in all.")
    end

    it "says click for a single click in the lede" do
      relation.by_pk(made.id).update(click_count: 1)
      get "/admin/links"

      expect(page.find(".page-head-sub").text).to start_with("1 short link on shares.localhost, 1 click in all.")
    end
  end

  describe "search and sort" do
    before do
      link("https://github.com/aaronmallen", at: Time.utc(2026, 9, 1), clicks: 9)
      link("https://example.com/slides", code: "deck", at: Time.utc(2026, 9, 2), clicks: 1)
      link("https://example.org/", title: "Recording", at: Time.utc(2026, 9, 3), clicks: 4)
    end

    it "lists the newest first" do
      get "/admin/links"

      expect(titles).to eq(%w[Recording example.com github.com])
    end

    it "lists the most clicked first" do
      get "/admin/links", sort: "clicks"

      expect(titles).to eq(%w[github.com Recording example.com])
    end

    it "matches the title, destination and code", :aggregate_failures do
      { "record" => %w[Recording], "github" => %w[github.com], "deck" => %w[example.com] }.each do |search, found|
        get "/admin/links", search: search

        expect(titles).to eq(found)
      end
      expect(page).to have_css(".file-search .hint", text: "1 match")
    end

    it "keeps the sort when searching" do
      get "/admin/links", sort: "clicks", search: "example"

      expect(titles).to eq(%w[Recording example.com])
    end

    it "keeps the search when sorting" do
      get "/admin/links", search: "example"

      switch = "form:has([type=radio][name=sort])"

      expect(page).to have_css("#{switch} [type=hidden][name=search][value=example]", visible: :hidden)
    end

    it "says when nothing matches" do
      get "/admin/links", search: "nothing"

      expect(page).to have_css(".empty", text: i18n.t("ui.views.links.index.no_match"))
    end
  end

  describe "paging" do
    before { 16.times { link("https://example.com/#{it}", title: "link #{it}", at: Time.utc(2026, 9, 1 + it)) } }

    it "shows fifteen and links to the rest", :aggregate_failures do
      get "/admin/links", sort: "clicks"

      expect(titles).to eq((1..15).map { "link #{16 - it}" })
      expect(page).to have_css("nav.pager a[rel='next'][href='/admin/links?sort=clicks&page=2']")
    end

    it "shows the rest on the next page" do
      get "/admin/links", page: "2"

      expect(titles).to eq(["link 0"])
    end

    it "returns 404 past the end" do
      get "/admin/links", page: "3"

      expect(last_response).to be_not_found
    end
  end

  describe "the form" do
    it "posts to the links route", :aggregate_failures do
      get "/admin/links"
      form = page.find("form.link-new[action='/admin/links'][method='post']")

      expect(form).to have_field("link[destination]")
      expect(form).to have_field("link[code]")
      expect(form).to have_button("Shorten")
    end

    it "makes a link with a random code and says so", :aggregate_failures do
      shorten(destination: " https://example.com/talk ", code: "")
      follow_redirect!

      expect(links.map { [it[:destination], it[:code].length] }).to eq([["https://example.com/talk", 3]])
      expect(page).to have_css("[data-toast]", text: "Shortened")
    end

    it "makes a link with my code" do
      shorten(destination: "https://example.com/talk", code: "talk")

      expect(links.map { it[:code] }).to eq(%w[talk])
    end

    it "answers a script with the link", :aggregate_failures do
      shorten(destination: "https://example.com/talk", code: "talk", accept: "application/json")

      expect(last_response.status).to eq(201)
      expect(json).to eq("link" => "http://shares.localhost/talk", "message" => "Shortened")
    end

    it "refuses a link that is not a web link and keeps what I typed", :aggregate_failures do
      shorten(destination: "javascript:alert(1)", code: "talk")

      expect(last_response.status).to eq(422)
      expect(page).to have_css("#link-destination[aria-invalid] + .field-error", text: error("destination.format"))
      expect(%w[#link-destination #link-code].map { page.find(it).value }).to eq(["javascript:alert(1)", "talk"])
    end

    it "refuses a code another link holds" do
      link(code: "talk")
      shorten(destination: "https://example.com/other", code: "talk")

      expect(page).to have_css(".field-error", text: error("code.taken"))
    end

    it "refuses a code that breaks the format" do
      shorten(destination: "https://example.com/other", code: "no--way")

      expect(page).to have_css(".field-error", text: error("code.format"))
    end

    it "refuses a blank link" do
      shorten(destination: " ")

      expect(page).to have_css(".field-error", text: error("destination.blank"))
    end

    describe "a link I shortened before" do
      before do
        link(code: "talk")
        shorten(destination: "https://example.com/talk")
      end

      it "names its code and makes nothing yet", :aggregate_failures do
        expect(last_response.status).to eq(422)
        expect(page).to have_css(".link-new .hint", text: again_hint)
        expect(links.size).to eq(1)
      end

      it "makes a second when I shorten it again", :aggregate_failures do
        again = page.find("input[name='link[again]']", visible: :all).value
        shorten(destination: "https://example.com/talk", again:)

        expect(last_response).to be_redirect
        expect(links.size).to eq(2)
      end

      it "asks again when I change the link before shortening" do
        link("https://example.com/other", code: "other")
        shorten(destination: "https://example.com/other", again: "https://example.com/talk")

        expect(last_response.status).to eq(422)
      end
    end
  end

  describe "a drawer" do
    let!(:made) { link("https://www.example.com/talk", code: "talk", at: Time.utc(2026, 9, 3, 12), clicks: 1) }
    let(:drawer) { page.find("dialog#link-#{made.id}-drawer", visible: :all) }
    let(:confirm) { i18n.t("ui.components.links.link_form.confirm_delete", link: "shares.localhost/talk") }

    before { get "/admin/links" }

    it "opens from the row's title, which links to the edit page without scripts" do
      expect(page).to have_css(
        ".link-row-title a[href='/admin/links/#{made.id}/edit'][data-dialog-open='link-#{made.id}-drawer']",
      )
    end

    it "shows the title, clicks, date and last click", :aggregate_failures do
      Shares::Slice["relations.short_links"].by_pk(made.id).update(last_clicked_at: Time.utc(2026, 9, 5, 12))
      get "/admin/links"

      expect(drawer).to have_css(".file-drawer-name", exact_text: "example.com", visible: :all)
      expect(drawer.find(".file-drawer-meta", visible: :all).text(:all))
        .to include("1 click", "made September 3, 2026", "last clicked Sep 5, 2026")
    end

    it "copies the link and the host as markdown", :aggregate_failures do
      expect(drawer).to have_css(".file-drawer-link", exact_text: "http://shares.localhost/talk", visible: :all)
      expect(drawer).to have_css("button[data-record-key='http://shares.localhost/talk']", visible: :all)
      expect(drawer).to have_css("button[data-record-key='[example.com](http://shares.localhost/talk)']", visible: :all)
    end

    it "copies the title as markdown once it has one" do
      Shares::Slice["operations.set_short_link_title"].call(made.id, { title: "My talk" })
      get "/admin/links"

      expect(drawer).to have_css("button[data-record-key='[My talk](http://shares.localhost/talk)']", visible: :all)
    end

    it "escapes brackets and backslashes in the title it copies as markdown" do
      Shares::Slice["operations.set_short_link_title"].call(made.id, { title: "My [talk] \\ slides" })
      get "/admin/links"
      copy = drawer.find("button[data-record-key^='[']", visible: :all)

      expect(copy["data-record-key"]).to eq("[My \\[talk\\] \\\\ slides](http://shares.localhost/talk)")
    end

    it "edits the destination, code and title", :aggregate_failures do
      expect(drawer).to have_field("link[destination]", with: "https://www.example.com/talk", visible: :all)
      expect(drawer).to have_field("link[code]", with: "talk", visible: :all)
      expect(drawer).to have_field("link[title]", with: "", visible: :all)
    end

    it "asks before it deletes", :aggregate_failures do
      expect(page).to have_css(
        "form#link-#{made.id}-delete[action='/admin/links/#{made.id}/delete'][data-confirm='#{confirm}']",
        visible: :all,
      )
      expect(drawer).to have_css("button[form='link-#{made.id}-delete']", visible: :all)
    end
  end

  describe "the edit page" do
    it "shows the form without scripts", :aggregate_failures do
      made = link(code: "talk")
      get "/admin/links/#{made.id}/edit"

      expect(page).to have_css("form[action='/admin/links/#{made.id}'] input[name='link[destination]']")
      expect(page).to have_css("button[form='link-#{made.id}-form'][type='submit']")
    end

    it "answers 404 for a missing link" do
      get "/admin/links/0/edit"

      expect(last_response).to be_not_found
    end
  end

  describe "saving" do
    let(:made) { link(code: "talk") }
    let(:server) { Rack::MockRequest.new(Shares::Slice["server"]) }

    def fields = { destination: "https://example.com/talk", code: "talk", title: "" }

    def save(**changes)
      post("/admin/links/#{made.id}", { link: fields.merge(changes) }, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token })
    end

    def stored = relation.with_code.by_pk(made.id).one.to_h.slice(:destination, :code, :title)

    it "says it saved" do
      save(title: "My talk")
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: i18n.t("links_page.toasts.saved"))
    end

    it "sends the code to a new destination" do
      save(destination: "https://example.org/talk")

      expect(server.get("/talk").headers["Location"]).to eq("https://example.org/talk")
    end

    it "keeps the short link when the destination changes, as the lede says", :aggregate_failures do
      save(destination: "https://example.org/talk")
      get "/admin/links"

      expect(page.find(".page-head-sub").text).to end_with("any time; the short link stays the same.")
      expect(stored).to include(code: "talk", destination: "https://example.org/talk")
    end

    it "answers at the new code and 404 at the old one", :aggregate_failures do
      save(code: "keynote")

      expect(server.get("/keynote").headers["Location"]).to eq("https://example.com/talk")
      expect(server.get("/talk").status).to eq(404)
    end

    it "saves the title" do
      save(title: "My talk")

      expect(stored[:title]).to eq("My talk")
    end

    describe "refused" do
      let!(:was) { stored }

      before do
        link("https://example.com/other", code: "other")
        Shares::Slice["relations.short_codes"].command(:create).call(code: "deck")
      end

      {
        "a bad destination" => [{ destination: "javascript:alert(1)" }, "destination.format"],
        "a blank code" => [{ code: " " }, "code.blank"],
        "a code another link holds" => [{ code: "other" }, "code.taken"],
        "a code a share holds" => [{ code: "deck" }, "code.taken"],
      }.each do |name, (changes, reason)|
        it "refuses #{name} and changes nothing", :aggregate_failures do
          save(title: "My talk", destination: "https://example.org/talk", **changes)

          expect(last_response.status).to eq(422)
          expect(page).to have_css(".field-error", text: error(reason))
          expect(stored).to eq(was)
        end
      end
    end

    it "keeps what I typed when it refuses" do
      save(code: "no--way", title: "My talk")

      expect(%w[code title].map { page.find("#link-#{made.id}-#{it}").value }).to eq(["no--way", "My talk"])
    end

    describe "the hints" do
      def copies?(markdown) = page.has_css?("[data-record-key='#{markdown}']", visible: :all)

      def hint(key, **) = i18n.t(key, scope: "ui.components.links.link_form", **)

      def hints
        get "/admin/links/#{made.id}/edit"
        page.all(".hint").map(&:text)
      end

      it "says where the link sends people" do
        save(destination: "https://example.org/talk")

        expect([server.get("/talk").headers["Location"], hints])
          .to match(["https://example.org/talk", include(hint("destination_hint", link: "shares.localhost/talk"))])
      end

      it "says a new code moves the link and the old one stops working" do
        save(code: "keynote")

        expect([server.get("/keynote").headers["Location"], server.get("/talk").status, hints])
          .to match(["https://example.com/talk", 404, include(hint("code_hint", host: "shares.localhost"))])
      end

      it "says only I see the title, and search and markdown use it" do
        save(title: "My talk")
        shown = hints
        get "/admin/links", search: "my talk"

        expect([titles, copies?("[My talk](http://shares.localhost/talk)"), shown])
          .to match([["My talk"], true, include(hint("title_hint"))])
      end
    end
  end

  describe "deleting" do
    let(:made) { link(code: "talk") }

    def delete_link(id = made.id) = post("/admin/links/#{id}/delete", {}, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token })

    it "removes the link and frees its code", :aggregate_failures do
      delete_link

      expect(links).to be_empty
      expect(Rack::MockRequest.new(Shares::Slice["server"]).get("/talk").status).to eq(404)
    end

    it "says it deleted" do
      delete_link
      follow_redirect!

      expect(page).to have_css("[data-toast]", text: i18n.t("links_page.toasts.deleted"))
    end

    it "answers 404 for a missing link" do
      delete_link(0)

      expect(last_response).to be_not_found
    end
  end

  describe "the destination's title", :commits do
    let(:fetches) { Shares::Jobs::FetchShortLinkTitle }

    before { resolves_publicly("example.com", "example.org") }

    def listed
      fetches.drain
      get "/admin/links"
      titles
    end

    def page_titled(url, title)
      stub_request(:get, url).to_return(body: "<title>#{title}</title>", headers: { "Content-Type" => "text/html" })
    end

    def save(made, **changes)
      fields = { destination: made.destination, code: made.code, title: "" }.merge(changes)
      post("/admin/links/#{made.id}", { link: fields }, { "HTTP_X_CSRF_TOKEN" => admin_csrf_token })
    end

    it "names a link I shorten after its page" do
      page_titled("https://example.com/talk", "My talk")
      shorten(destination: "https://example.com/talk")

      expect(listed).to eq(["My talk"])
    end

    it "shows the host when the page will not answer" do
      stub_request(:get, "https://example.com/talk").to_return(status: 503)
      shorten(destination: "https://example.com/talk")

      expect(listed).to eq(["example.com"])
    end

    it "fetches again when I clear the title and save" do
      made = link(title: "Old")
      page_titled("https://example.com/talk", "My talk")
      save(made)

      expect(listed).to eq(["My talk"])
    end

    it "fetches the new destination's title when I retarget a link with none" do
      made = link
      fetches.clear
      page_titled("https://example.org/deck", "My deck")
      save(made, destination: "https://example.org/deck")

      expect(listed).to eq(["My deck"])
    end

    it "keeps my title when I retarget a titled link", :aggregate_failures do
      made = link(title: "Mine")
      save(made, destination: "https://example.org/deck", title: "Mine")

      expect(fetches.jobs).to be_empty
      expect(listed).to eq(["Mine"])
    end

    it "queues nothing when it refuses the save" do
      made = link(title: "Mine")
      save(made, destination: "javascript:alert(1)")

      expect(fetches.jobs).to be_empty
    end
  end
end
