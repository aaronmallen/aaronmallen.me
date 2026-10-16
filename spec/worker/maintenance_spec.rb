# frozen_string_literal: true

RSpec.describe "The worker during maintenance", type: :app do
  let(:error) { RuntimeError.new("boom") }
  let(:flag) { Hanami.app.root.join("tmp/maintenance-#{SecureRandom.hex}").to_s }
  let(:notices) { [] }
  let(:runs) { [] }

  let(:job) do
    ran = runs
    stub_const("Spec::MaintainedJob", Class.new(Blog::Job) { define_method(:perform) { ran << :ran } })
  end

  def agent = Hanami.app["honeybadger.agent"]

  def run
    job.perform_async
    job.drain
  end

  before do
    allow(Hanami.app.settings).to receive(:maintenance).and_return(flag_path: flag)
    record = ->(build, *args) { build.call(*args).tap { notices << it } }
    allow(Honeybadger::Notice).to receive(:new).and_wrap_original(&record)
    Sidekiq::Testing.server_middleware { it.add Blog::JobMaintenance, flag }
  end

  after do
    Sidekiq::Testing.server_middleware { it.remove Blog::JobMaintenance }
    FileUtils.rm_f(flag)
  end

  context "when the flag file exists" do
    before { FileUtils.touch(flag) }

    it "skips the job's work" do
      run

      expect(runs).to be_empty
    end

    it "clears the job from the queue" do
      run

      expect(job.jobs).to be_empty
    end

    it "sends Honeybadger nothing" do
      agent.notify(error)

      expect(notices).to contain_exactly(have_attributes(exception: error, halted?: true))
    end

    it "runs jobs and reports again once the file is gone", :aggregate_failures do
      FileUtils.rm(flag)
      run
      agent.notify(error)

      expect(runs).to eq([:ran])
      expect(notices).to contain_exactly(have_attributes(exception: error, halted?: false))
    end
  end

  context "when the flag file is absent" do
    it "runs the job" do
      run

      expect(runs).to eq([:ran])
    end

    it "tells Honeybadger" do
      agent.notify(error)

      expect(notices).to contain_exactly(have_attributes(exception: error, halted?: false))
    end
  end
end
