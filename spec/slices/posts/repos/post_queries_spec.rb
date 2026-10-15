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
end
