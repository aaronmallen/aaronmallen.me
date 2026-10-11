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
      .to eq(%w[/admin/posts /admin/social /admin/projects /admin/files /admin/links])
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

      expect(links.map { [it[:destination], it[:code].length] }).to eq([["https://example.com/talk", 5]])
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
end
