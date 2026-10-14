# frozen_string_literal: true

RSpec.describe "Project keys", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }

  def project(name, key = nil) = db[:projects].insert(name:, visibility: "public", key:)

  %w[pod P POD-1 1POD PODCAST].each do |key|
    it "refuses #{key.inspect}" do
      expect { project("pod", key) }.to raise_error(Sequel::CheckConstraintViolation)
    end
  end

  it "refuses a key another project holds" do
    project("first", "POD")

    expect { project("second", "POD") }.to raise_error(Sequel::UniqueConstraintViolation)
  end

  it "gives each project a key in id order when its key is cleared, as the migration does" do
    ids = %w[AA BB CC].map { project("pod", it) }
    ids.each { |id| db[:projects].where(id:).update(key: nil) }

    expect(db[:projects].where(id: ids).order(:id).select_map(:key)).to eq(%w[POD POD2 POD3])
  end

  it "falls back to PRJ for a name with no letters in it" do
    id = project("42")

    expect(db[:projects].where(id:).get(:key)).to eq("PRJ")
  end
end
