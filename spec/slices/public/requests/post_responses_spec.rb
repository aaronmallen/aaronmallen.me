# frozen_string_literal: true

RSpec.describe "Post responses", type: :request do
  subject(:page) { Capybara.string(last_response.body) }

  let(:post_record) { create(:post, :published, slug: "hello") }

  def mention(*traits, **attrs)
    create(:webmention, *traits, post: post_record, **attrs)
  end

  describe "the responses section" do
    describe "an approved reply" do
      before do
        mention(:approved, :reply, author_name: "Ada", excerpt: "Good one", received_at: Time.utc(2026, 9, 7, 12))
        get "/writing/hello"
      end

      it "heads the section" do
        expect(page.find(".post-responses")).to have_text("Responses")
      end

      it "shows the author, the date and the excerpt", :aggregate_failures do
        expect(page).to have_css(".post-response .p-name", text: "Ada")
        expect(page).to have_css(".post-response time", text: "Sep 7, 2026")
        expect(page).to have_css(".post-response-text", text: "Good one")
      end
    end

    it "lists them oldest first" do
      mention(:approved, :reply, author_name: "Bea", received_at: Time.now - 60)
      mention(:approved, :mention, author_name: "Ada", received_at: Time.now - 120)
      get "/writing/hello"

      expect(page.all(".post-response .p-name").map(&:text)).to eq(%w[Ada Bea])
    end

    it "links the author to the source and marks the link up for a stranger", :aggregate_failures do
      mention(:approved, :reply, source_url: "https://ada.example/reply")
      get "/writing/hello"

      link = page.find(".post-response-author")

      expect(link[:href]).to eq("https://ada.example/reply")
      expect(link[:rel].to_s.split).to contain_exactly("nofollow", "noopener", "ugc")
    end

    it "falls back to the author's domain when the mention has no name" do
      mention(:approved, :reply, author_name: nil, author_url: "https://ada.example/about")
      get "/writing/hello"

      expect(page).to have_css(".post-response .p-name", text: "ada.example")
    end

    it "leaves out the excerpt when the mention has none" do
      mention(:approved, :reply, excerpt: " ")
      get "/writing/hello"

      expect(page).to have_no_css(".post-response-text")
    end

    it "leaves out pending and spam mentions", :aggregate_failures do
      mention(:reply, author_name: "Pending")
      mention(:spam, :reply, author_name: "Spam")
      get "/writing/hello"

      expect(page).to have_no_css(".post-responses")
      expect(page).to have_no_text("Pending").and have_no_text("Spam")
    end

    it "leaves out ignored replies and mentions", :aggregate_failures do
      mention(:ignored, :reply, author_name: "Ignored reply")
      mention(:ignored, :mention, author_name: "Ignored mention")
      get "/writing/hello"

      expect(page).to have_no_css(".post-responses")
      expect(page).to have_no_text("Ignored reply").and have_no_text("Ignored mention")
    end

    it "renders nothing when the post has no approved mentions", :aggregate_failures do
      post_record
      get "/writing/hello"

      expect(last_response).to be_ok
      expect(page).to have_no_css(".post-responses")
    end

    it "leaves out mentions of another post", :aggregate_failures do
      post_record
      create(:webmention, :approved, :reply, post: create(:post, :published))
      get "/writing/hello"

      expect(last_response).to be_ok
      expect(page).to have_no_css(".post-responses")
    end
  end

  describe "the like and repost counts" do
    it "counts approved likes and reposts" do
      2.times { mention(:approved, :like) }
      mention(:approved, :repost)
      get "/writing/hello"

      expect(page).to have_css(".post-response-counts", text: "2 likes · 1 repost")
    end

    it "leaves out a type nobody sent" do
      mention(:approved, :like)
      get "/writing/hello"

      expect(page.find(".post-response-counts")).to have_text("1 like").and have_no_text("repost")
    end

    it "shows the counts with no replies to list", :aggregate_failures do
      mention(:approved, :like)
      get "/writing/hello"

      expect(page).to have_css(".post-responses")
      expect(page).to have_no_css(".post-response-list")
    end

    it "leaves out pending and spam likes" do
      mention(:like)
      mention(:spam, :like)
      get "/writing/hello"

      expect(page).to have_no_css(".post-responses")
    end

    it "leaves out ignored likes and reposts" do
      mention(:approved, :like)
      mention(:ignored, :like)
      mention(:ignored, :repost)
      get "/writing/hello"

      expect(page.find(".post-response-counts")).to have_text("1 like").and have_no_text("repost")
    end
  end

  describe "the endpoint link" do
    it "advertises the endpoint on a post with webmentions on" do
      post_record
      get "/writing/hello"

      expect(page).to have_css("head link[rel='webmention'][href='/webmention']", visible: :all)
    end

    it "leaves the link out on a post with webmentions off" do
      create(:post, :published, slug: "quiet", webmentions_enabled: false)
      get "/writing/quiet"

      expect(page).to have_no_css("head link[rel='webmention']", visible: :all)
    end

    it "leaves the link out on the writing index" do
      post_record
      get "/writing"

      expect(page).to have_no_css("head link[rel='webmention']", visible: :all)
    end
  end
end
