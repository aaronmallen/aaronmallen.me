# frozen_string_literal: true

RSpec.describe Posts::Repos::PostQueries do
  subject(:post_queries) { Posts::Slice["repos.post_queries"] }

  let(:posts) do
    [2, 1, 0].map { create(:post, :published, published_at: Time.now - (it * 60)) }
  end

  describe "the pager" do
    it "reads only what it draws", :aggregate_failures do
      expect(post_queries.previous_published(posts[1]).to_h.keys).to contain_exactly(:title, :slug, :published_at)
      expect(post_queries.next_published(posts[1]).to_h.keys).to contain_exactly(:title, :slug, :published_at)
    end
  end

  describe "the sitemap" do
    it "reads only the columns it prints" do
      posts
      read = post_queries.sitemap_posts.map(&:to_h)

      expect(read.map(&:keys)).to all(contain_exactly(:id, :slug, :published_at, :updated_at))
    end
  end

  describe "the lists" do
    let!(:tagged) { Array.new(3) { create(:post, :published, tags: %w[ruby]) } }
    let(:page) { Blog::Structs::Page.new(number: 1, size: 10) }
    let(:window) { { from: Blog::TimeZone.today - 2, to: Blog::TimeZone.today } }
    let(:lists) do
      [
        post_queries.by_tag("ruby"), post_queries.by_ids(tagged.map(&:id)), post_queries.by_filter("all", page).rows,
        post_queries.dated_between(**window, page:).rows, post_queries.calendar_between(**window),
      ]
    end

    it "reads no bodies", :aggregate_failures do
      expect(lists.map(&:size)).to all(eq(3))
      expect(lists.flatten.map { it.to_h.keys & %i[body body_html syndication_body search_vector] }).to all(be_empty)
    end

    it "keeps the tags" do
      expect(lists.flatten.map { it.tags.map(&:name) }).to all(eq(%w[ruby]))
    end
  end
end
