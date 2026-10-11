# frozen_string_literal: true

RSpec.describe Social::Operations::SaveSocialPost do
  let(:photos) { Array.new(5) { create(:photo, created_at: Time.now - (3 * 24 * 60 * 60)) } }

  def claims = Media::Slice["relations.photo_claims"].where(owner: "social_post_part").to_a

  def held = Social::Slice["relations.social_post_photos"].in_order.to_a

  def keys = Media::Slice["relations.photos"].to_a.map { it[:key] }

  def part_ids(social_post) = social_post.parts.map(&:id)

  def photo(index, part: 1, alt: nil) = { part:, key: photos[index].key, alt: }

  def save(id: nil, parts: %w[one two], **attrs)
    Social::Slice["operations.save_social_post"].call(id:, parts:, targets: %w[mastodon], status: "draft", **attrs)
  end

  before do
    connect_media_store
    stub_request(:delete, /store\.example/)
  end

  it "stores each photo on its part, in order, with its alt text" do
    ids = part_ids(save(photos: [photo(0, alt: "A cat"), photo(1, part: 2), photo(2, alt: "A dog")]).value!)
    stored = [[ids[0], 1, photos[0].key, "A cat"], [ids[0], 2, photos[2].key, "A dog"], [ids[1], 1, photos[1].key, nil]]

    expect(held.map { it.values_at(:social_post_part_id, :position, :photo_key, :alt_text) }).to match_array(stored)
  end

  it "claims the photos for the part that holds them" do
    social_post = save(photos: [photo(0), photo(1, part: 2)]).value!

    expect(claims.map { [it[:owner_id], it[:photo_id]] }).to contain_exactly(
      [social_post.parts[0].id, photos[0].id], [social_post.parts[1].id, photos[1].id],
    )
  end

  it "drops the claim on a photo taken out of a part" do
    social_post = save(photos: [photo(0), photo(1)]).value!
    save(id: social_post.id, photos: [photo(1)])

    expect(claims.map { it[:photo_id] }).to eq([photos[1].id])
  end

  it "keeps the photos when a save leaves them out" do
    social_post = save(photos: [photo(0)]).value!
    save(id: social_post.id, parts: %w[edited two])

    expect([held.map { it[:photo_key] }, claims.map { it[:photo_id] }]).to eq([[photos[0].key], [photos[0].id]])
  end

  it "keeps the photos when an accepted suggestion rewrites the parts" do
    social_post = save(photos: [photo(0)]).value!
    Social::Slice["operations.replace_social_post_parts"].call(social_post.id, %w[edited two])

    expect(held.map { it[:social_post_part_id] }).to eq([social_post.parts[0].id])
  end

  it "releases and deletes the photos of a part a save drops", :aggregate_failures, :commits do
    social_post = save(photos: [photo(0, part: 2)]).value!
    save(id: social_post.id, parts: %w[one])

    expect([held, claims]).to eq([[], []])
    expect(keys).not_to include(photos[0].key)
  end

  it "releases its photos on delete, and the last release deletes the photo", :aggregate_failures, :commits do
    Social::Slice["operations.delete_social_post"].call(save(photos: [photo(0)]).value!.id)

    expect([held, claims, keys]).to eq([[], [], photos.drop(1).map(&:key)])
    expect(a_request(:delete, media_store_url(photos[0].key))).to have_been_made
  end

  it "keeps a photo on delete while another post holds it", :commits do
    other = save(photos: [photo(0)]).value!
    Social::Slice["operations.delete_social_post"].call(save(photos: [photo(0)]).value!.id)

    expect(claims.map { it.values_at(:owner_id, :photo_id) }).to eq([[other.parts[0].id, photos[0].id]])
  end

  it "refuses a fifth photo on a part" do
    result = save(photos: Array.new(5) { photo(it) })

    expect(result.failure).to eq([:invalid, { photos: ["many"] }])
  end

  it "takes four photos on each of two parts" do
    result = save(photos: Array.new(4) { photo(it) } + Array.new(4) { photo(it, part: 2) })

    expect(result).to be_success
  end

  it "refuses a photo on a part the post does not have" do
    expect(save(photos: [photo(0, part: 3)]).failure).to eq([:invalid, { photos: ["missing"] }])
  end

  it "refuses a key no photo carries" do
    expect(save(photos: [{ part: 1, key: "#{'f' * 32}.png" }]).failure).to eq([:invalid, { photos: ["missing"] }])
  end

  it "refuses a fifth photo in the database" do
    social_post = save(photos: Array.new(4) { photo(it) }).value!
    row = { social_post_part_id: social_post.parts[0].id, position: 5, photo_key: photos[4].key }

    expect { Social::Slice["relations.social_post_photos"].command(:create).call(row) }
      .to raise_error(ROM::SQL::CheckConstraintError)
  end

  it "keeps a photo through the sweep while a part holds it" do
    save(photos: [photo(0)])
    Media::Slice["operations.sweep_photos"].call

    expect(keys).to eq([photos[0].key])
  end
end
