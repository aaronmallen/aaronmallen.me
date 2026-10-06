# frozen_string_literal: true

RSpec.describe Analytics::Queries::UniqueReaders do
  def post(slug, days_ago = 0) = create(:post, :published, slug:, published_at: Time.now - (days_ago * 86_400))

  def readers(*posts) = Analytics::Slice["queries.unique_readers"].call(posts).transform_values(&:values)

  it "gives each post its readers by id in one call, new, saved and uncounted alike" do
    create(:post_reader_hash, path: "/writing/fresh")
    create(:post_reader_count, path: "/writing/saved", readers: 1234)
    posts = [post("fresh"), post("unread"), post("saved", 400), post("lost", 400)]

    expect(readers(*posts).values_at(*posts.map(&:id))).to eq([[1, false], [0, false], [1234, true], [nil, true]])
  end
end
