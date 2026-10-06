# frozen_string_literal: true

RSpec.describe "Footer", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  let(:profiles) do
    {
      bluesky: { profile_url: "https://bsky.example/ada" },
      github: { profile_url: "https://github.example/ada" },
      mastodon: { profile_url: "https://social.example/@ada" },
    }
  end

  before do
    allow(Hanami.app.settings).to receive_messages(**profiles)
    get "/"
  end

  def profile_links = page.all("footer.site-footer a.site-footer-link")

  it "keeps the copyright beside the name, in this year" do
    expect(page.find("footer .h-card").text).to start_with("© #{Blog::TimeZone.today.year} Aaron Allen")
  end

  it "marks the site owner's link rel=me and keeps it in this tab", :aggregate_failures do
    link = page.find("footer .h-card a.p-name")

    expect(link[:rel]).to eq("me")
    expect(link[:target]).to be_nil
  end

  it "opens the built with links in a new tab, with no handle back to this one" do
    expect(page.all("footer a.site-footer-text-link[target='_blank'][rel='noopener']").map(&:text))
      .to eq(%w[Hanami Phlex])
  end

  it "keeps every profile link in this tab" do
    expect(profile_links.map { it[:target] }).to all(be_nil)
  end

  it "labels each profile link" do
    expect(profile_links.map { it.text.strip }).to eq(%w[github bluesky mastodon])
  end

  it "hides each profile link's icon from assistive tech" do
    expect(profile_links.map { it.find("i", visible: :all)["aria-hidden"] }).to all(eq("true"))
  end

  it "labels the heart as an image", :aggregate_failures do
    heart = page.find("footer i.fa-heart", visible: :all)

    expect(heart[:role]).to eq("img")
    expect(heart["aria-label"]).to eq("love")
    expect(heart["aria-hidden"]).to be_nil
  end

  %w[/ /about /contact /privacy /projects /writing].each do |path|
    it "links #{path} to the privacy page" do
      get path

      expect(page.find("footer.site-footer")).to have_link("privacy", href: "/privacy", exact: true)
    end
  end

  it "links a post and its tag to the privacy page", :aggregate_failures do
    post = create(:post, :published, tags: %w[ruby])

    ["/writing/#{post.slug}", "/writing/tags/ruby"].each do |path|
      get path

      expect(page.find("footer.site-footer")).to have_link("privacy", href: "/privacy", exact: true)
    end
  end

  context "with a network left unconfigured" do
    let(:profiles) { { bluesky: {}, github: { profile_url: "https://github.example/ada" }, mastodon: {} } }

    it "leaves the unconfigured networks out" do
      expect(profile_links.map { it[:href] }).to eq(["https://github.example/ada"])
    end
  end

  context "with a profile url that is blank" do
    let(:profiles) { { bluesky: { profile_url: "  " }, github: {}, mastodon: {} } }

    it "renders no link for it" do
      expect(profile_links).to be_empty
    end
  end

  context "with a profile url that is not a url" do
    let(:profiles) { { bluesky: { profile_url: "bskyapp/ada" }, github: {}, mastodon: {} } }

    it "renders no link for it" do
      expect(profile_links).to be_empty
    end
  end
end
