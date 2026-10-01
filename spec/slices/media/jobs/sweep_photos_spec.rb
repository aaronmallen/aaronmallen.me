# frozen_string_literal: true

RSpec.describe Media::Jobs::SweepPhotos, type: :request do
  let(:day) { 24 * 60 * 60 }

  def claim(photo)
    Media::Slice["relations.photo_claims"].command(:create).call(owner: "post", owner_id: 1, photo_id: photo.id)
  end

  def keys = Media::Slice["relations.photos"].to_a.map { it[:key] }

  def sweep = described_class.new.perform

  def uploaded(ago) = create(:photo, created_at: Time.now - ago)

  before do
    connect_media_store
    stub_request(:delete, /store\.example/)
  end

  it "runs on the schedule the worker reads" do
    expect(Object.const_get(sidekiq_schedule("sweep_photos").fetch("class"))).to eq(described_class)
  end

  it "deletes a photo unclaimed for a day from the table and the store", :aggregate_failures do
    photo = uploaded(day + 60)
    sweep

    expect(keys).to be_empty
    expect(a_request(:delete, media_store_url(photo.key))).to have_been_made
  end

  it "keeps a photo uploaded less than a day ago", :aggregate_failures do
    photo = uploaded(day - 60)
    sweep

    expect(keys).to eq([photo.key])
    expect(a_request(:delete, media_store_url(photo.key))).not_to have_been_made
  end

  it "keeps an old photo something claims" do
    photo = uploaded(day * 3)
    claim(photo)
    sweep

    expect(keys).to eq([photo.key])
  end

  it "keeps a photo whose store delete fails, for the next run" do
    photo = uploaded(day + 60)
    stub_request(:delete, media_store_url(photo.key)).to_timeout
    sweep

    expect(keys).to eq([photo.key])
  end
end
