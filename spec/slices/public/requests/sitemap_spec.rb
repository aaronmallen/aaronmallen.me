# frozen_string_literal: true

RSpec.describe "Sitemap", type: :request do
  let(:schema) { Nokogiri::XML::Schema(File.read(File.expand_path("../../../support/schemas/sitemap.xsd", __dir__))) }
  let(:sitemap) { Nokogiri::XML(last_response.body, &:strict) }

  def lastmod(loc) = sitemap.at_xpath("//xmlns:url[xmlns:loc='#{loc}']/xmlns:lastmod")&.text

  def listed
    %w[/ /about /projects /contact /writing /writing/hello /writing/again /writing/tags/hanami /writing/tags/ruby]
  end

  def locs = sitemap.xpath("//xmlns:url/xmlns:loc").map(&:text)

  def publish(slug, **attrs) = create(:post, :published, slug:, **attrs)

  def site(path) = "https://aaronmallen.me#{path}"

  it "serves a valid sitemap", :aggregate_failures do
    publish("hello", tags: %w[ruby])
    get "/sitemap.xml"

    expect(last_response.media_type).to eq("application/xml")
    expect(schema.validate(sitemap)).to be_empty
  end

  it "answers a crawler that takes anything" do
    get "/sitemap.xml", {}, "HTTP_ACCEPT" => "*/*"

    expect(last_response.media_type).to eq("application/xml")
  end

  it "lists the public pages, published posts and their tags" do
    publish("hello", tags: %w[ruby hanami])
    publish("again", tags: %w[ruby])
    get "/sitemap.xml"

    expect(locs).to match_array(listed.map { site(it) })
  end

  it "leaves out drafts, scheduled posts and tags only they carry" do
    %i[draft scheduled].each { create(:post, it, slug: "hidden-#{it}", tags: %w[secret]) }
    get "/sitemap.xml"

    expect(locs).to eq(%w[/ /about /projects /contact /writing].map { site(it) })
  end

  it "lists the tags of live public projects" do
    create(:project, tags: %w[elixir])
    get "/sitemap.xml"

    expect(locs).to include(site("/writing/tags/elixir"))
  end

  it "leaves out tags only private or archived projects carry" do
    create(:project, :private, tags: %w[secret])
    create(:project, :archived, tags: %w[retired])
    get "/sitemap.xml"

    expect(locs).to eq(%w[/ /about /projects /contact /writing].map { site(it) })
  end

  it "lists each public project's published board, dated by its last change" do
    create(:project, name: "Board", board_published: true, updated_at: Time.utc(2026, 9, 4))
    get "/sitemap.xml"

    expect(lastmod(site("/projects/board"))).to eq("2026-09-04T00:00:00Z")
  end

  it "leaves out private projects and unpublished boards" do
    create(:project, :private, name: "Hidden", board_published: true)
    create(:project, name: "Unpublished")
    get "/sitemap.xml"

    expect(locs).to eq(%w[/ /about /projects /contact /writing].map { site(it) })
  end

  it "leaves out the admin, API and MCP paths" do
    get "/sitemap.xml"

    expect(locs.map { URI(it).path }).to all(satisfy { !it.start_with?("/admin", "/api", "/mcp") })
  end

  it "dates a post by its last change" do
    post_record = publish("hello", published_at: Time.utc(2026, 9, 1), updated_at: Time.utc(2026, 9, 3))
    get "/sitemap.xml"

    expect(lastmod(site("/writing/#{post_record.slug}"))).to eq("2026-09-03T00:00:00Z")
  end

  it "dates a post by its newest edit note when that is later" do
    post_record = publish("hello", published_at: Time.utc(2026, 9, 1), updated_at: Time.utc(2026, 9, 1))
    at = Time.utc(2026, 9, 5, 12)
    create(:post_edit, post: post_record, note: "fixed a typo", created_at: at, updated_at: at)
    get "/sitemap.xml"

    expect(lastmod(site("/writing/hello"))).to eq("2026-09-05T12:00:00Z")
  end
end
