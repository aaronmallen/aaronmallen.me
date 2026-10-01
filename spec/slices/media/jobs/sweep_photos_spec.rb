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

  describe "a sweep and a save that meet on one photo", :commits do
    let(:gate) { Queue.new }
    let!(:photo) { uploaded(day * 2) }

    def claimed_ids = Media::Slice["relations.photo_claims"].pluck(:photo_id)

    def database = Media::Slice["db.rom"].gateways[:default].connection

    def meet(first, second)
      threads = [Thread.new(&first)]
      wait_at_gate
      threads << Thread.new(&second)
      wait_for_lock
      gate << :go
      threads.map(&:value)
    end

    def save = Media::Slice["operations.claim_photos"].call("post", 1, "/media/#{photo.key}")

    def save_holding_open = Media::Slice["repos.photo_repo"].transaction { save.tap { gate.pop } }

    def wait_at_gate = Timeout.timeout(5) { sleep(0.01) until gate.num_waiting.positive? }

    def wait_for_lock
      waiting = database[:pg_stat_activity].where(datname: Sequel.function(:current_database), wait_event_type: "Lock")
      Timeout.timeout(5) { sleep(0.01) until waiting.any? }
    end

    it "keeps a photo a save claims while the sweep waits", :aggregate_failures do
      meet(-> { save_holding_open }, -> { sweep })

      expect(keys).to eq([photo.key])
      expect(claimed_ids).to eq([photo.id])
      expect(a_request(:delete, media_store_url(photo.key))).not_to have_been_made
    end

    it "lets a save that waits on a sweep claim nothing", :aggregate_failures do
      stub_request(:delete, media_store_url(photo.key)).to_return { gate.pop && { status: 204 } }
      _, claimed = meet(-> { sweep }, -> { save })

      expect(claimed).to be_empty
      expect(keys).to be_empty
      expect(claimed_ids).to be_empty
    end
  end
end
