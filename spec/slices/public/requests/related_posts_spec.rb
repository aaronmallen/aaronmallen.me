# frozen_string_literal: true

RSpec.describe "Related posts", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def publish(slug, minutes_ago, body: "plain words", **attrs)
    create(:post, :published, slug:, title: slug.capitalize, body:, published_at: Time.now - (minutes_ago * 60),
                              **attrs)
  end

  def related = page.all(".rel li .rt").map(&:text)

  it "sits after the post extras and before the pager" do
    publish("hello", 1, tags: %w[ruby])
    publish("other", 2, tags: %w[ruby])
    get "/writing/hello"

    expect(page).to have_css("article.post > .post-extras + section.rel + nav.pgr")
  end

  it "shows at most three posts" do
    publish("hello", 1, tags: %w[ruby])
    (2..6).each { publish("other-#{it}", it, tags: %w[ruby]) }
    get "/writing/hello"

    expect(related).to eq(%w[Other-2 Other-3 Other-4])
  end

  it "ranks posts sharing more tags first, then the newest" do
    publish("hello", 1, tags: %w[ruby hanami rom])
    { "one-new" => %w[ruby], "two" => %w[ruby hanami], "one-old" => %w[rom] }
      .each.with_index(2) { |(slug, tags), minutes_ago| publish(slug, minutes_ago, tags:) }
    get "/writing/hello"

    expect(related).to eq(%w[Two One-new One-old])
  end

  it "names the tags a post shares with this one", :aggregate_failures do
    publish("hello", 1, tags: %w[ruby hanami])
    publish("other", 2, tags: %w[hanami rust])
    get "/writing/hello"

    expect(page.find(".rel li .rm")).to have_css("time").and have_text("shares")
    expect(page.all(".rel .rm a.post-tag").map { [it.text, it[:href]] }).to eq([%w[hanami /writing/tags/hanami]])
  end

  it "links each card to its post and shows its summary", :aggregate_failures do
    publish("hello", 1, tags: %w[ruby])
    publish("other", 2, tags: %w[ruby], summary: "a short summary")
    get "/writing/hello"

    expect(page).to have_css(".rel a.rt[href='/writing/other']", text: "Other")
    expect(page).to have_css(".rel p.rs", exact_text: "a short summary")
  end

  describe "with fewer than three posts sharing a tag" do
    before do
      publish("hello", 1, tags: %w[ruby], body: "providers wire the container together")
      publish("tagged", 2, tags: %w[ruby])
      publish("worded", 3, body: "a container holds providers")
      publish("unrelated", 4, body: "cats sleep all afternoon")
      get "/writing/hello"
    end

    it "fills the empty slots with posts in similar wording" do
      expect(related).to eq(%w[Tagged Worded])
    end

    it "labels each card with why it is related" do
      expect(page.all(".rel li .rm span").map(&:text)).to eq(["shares ruby", "similar wording"])
    end
  end

  it "ranks the closer wording first" do
    publish("hello", 1, body: "providers wire the container together")
    publish("near", 3, body: "providers wire a container")
    publish("far", 2, body: "a container")
    get "/writing/hello"

    expect(related).to eq(%w[Near Far])
  end

  it "leaves out drafts, scheduled posts and the post itself" do
    publish("hello", 1, tags: %w[ruby], body: "providers wire the container")
    create(:post, :draft, slug: "draft", tags: %w[ruby], body: "providers wire the container")
    create(:post, :scheduled, slug: "later", tags: %w[ruby], body: "providers wire the container")
    get "/writing/hello"

    expect(page).to have_no_css(".rel")
  end

  it "hides the block when no post qualifies" do
    publish("hello", 1, tags: %w[ruby], body: "providers wire the container")
    publish("other", 2, tags: %w[rust], body: "cats sleep all afternoon")
    get "/writing/hello"

    expect(page).to have_no_css(".rel")
  end

  it "counts no record link between posts" do
    hello = publish("hello", 1, body: "providers wire the container")
    other = publish("other", 2, body: "cats sleep all afternoon")
    Links::Slice["operations.link_records"].call("post", hello.id, { other_kind: "post", other_id: other.id }).value!
    get "/writing/hello"

    expect(page).to have_no_css(".rel")
  end
end
