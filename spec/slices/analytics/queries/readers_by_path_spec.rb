# frozen_string_literal: true

RSpec.describe Analytics::Queries::ReadersByPath do
  def readers(*paths) = Analytics::Slice["queries.readers_by_path"].call(paths)

  it "counts a post's stored hashes while its window is open" do
    2.times { create(:post_reader_hash, path: "/writing/hello") }

    expect(readers("/writing/hello")).to eq("/writing/hello" => { readers: 2, final: false })
  end

  it "returns the saved count, marked final, once the window closes" do
    create(:post_reader_count, path: "/writing/old", readers: 7)

    expect(readers("/writing/old")).to eq("/writing/old" => { readers: 7, final: true })
  end

  it "answers for each path asked and no other", :aggregate_failures do
    create(:post_reader_hash, path: "/writing/hello")
    create(:post_reader_hash, path: "/writing/other")
    create(:post_reader_count, path: "/writing/old", readers: 7)

    expect(readers("/writing/hello", "/writing/old").keys).to contain_exactly("/writing/hello", "/writing/old")
  end

  it "leaves out a path no one has read" do
    expect(readers("/writing/hello")).to be_empty
  end

  it "counts a window the nightly job has yet to close as live" do
    create(:post, :published, slug: "old", published_at: Time.now - (370 * 86_400))
    create(:post_reader_hash, path: "/writing/old")

    expect(readers("/writing/old")).to eq("/writing/old" => { readers: 1, final: false })
  end
end
