# frozen_string_literal: true

RSpec.describe Analytics::Repos::PostReaderQueries, "#readers_by_path" do
  def readers(*paths) = Analytics::Slice["repos.post_reader_queries"].readers_by_path(paths)

  it "counts a window the nightly job has yet to close as live" do
    create(:post, :published, slug: "old", published_at: Time.now - (370 * 86_400))
    create(:post_reader_hash, path: "/writing/old")

    expect(readers("/writing/old")).to eq("/writing/old" => { readers: 1, final: false })
  end
end
