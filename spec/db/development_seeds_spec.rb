# frozen_string_literal: true

require "tempfile"

RSpec.describe "Development seeds", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:seeds) { Hanami.app.root.join("config/db/seeds/development").glob("*.rb").sort.map(&:to_s) }
  let(:areas) do
    %i[
      posts memory_files memory_facts agent_sessions artifacts artifact_versions decisions decision_options
      decision_comments calendars calendar_events share_group_files share_groups short_links sign_ins devices
      known_devices sightings mail_accounts mail_threads mail_messages saved_views health_days workouts
      performance_requests performance_pages performance_jobs performance_rollups work_sessions notes note_folders
      note_links people
    ]
  end

  def counts = db.tables.sort.to_h { [it, db[it].count] }

  it "fills every admin area", :aggregate_failures do
    seeds.each { load it }

    areas.each { expect(db[it].count).to be_positive, "#{it} is empty" }
    expect(db[:sign_ins].exclude(dismissed_at: nil).count).to be_positive
    expect(db[:people].where(Sequel.lit("jsonb_array_length(emails) > 0")).count).to be_positive
  end

  it "adds nothing on a second run" do
    seeds.each { load it }

    expect { seeds.each { load it } }.not_to(change { counts })
  end

  it "fails when a seed file raises" do
    Tempfile.create(%w[broken .rb]) do |broken|
      broken.write("raise 'broken seed'\n")
      broken.flush

      expect { [*seeds, broken.path].each { load it } }.to raise_error(RuntimeError, "broken seed")
    end
  end
end
