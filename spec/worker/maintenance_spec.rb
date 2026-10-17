# frozen_string_literal: true

RSpec.describe "The worker during maintenance", type: :app do
  let(:error) { RuntimeError.new("boom") }
  let(:flag) { Hanami.app.root.join("tmp/maintenance-#{SecureRandom.hex}").to_s }
  let(:notices) { [] }
  let(:runs) { [] }

  let(:job) { job_class("Spec::MaintainedJob", Blog::Job) }

  def agent = Hanami.app["honeybadger.agent"]

  def job_class(name, base)
    ran = runs
    stub_const(name, Class.new(base) { define_method(:perform) { ran << :ran } })
  end

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

    it "puts a one-off job off for later", :aggregate_failures do
      job.perform_async
      job.perform_one

      expect(runs).to be_empty
      expect(job.jobs).to contain_exactly(include("at" => be > Time.now.to_f))
    end

    it "runs a put off job once the file is gone" do
      job.perform_async
      job.perform_one
      FileUtils.rm(flag)
      job.drain

      expect(runs).to eq([:ran])
    end

    it "skips a scheduled job and clears it from the queue", :aggregate_failures do
      scheduled = job_class("Spec::MaintainedScheduledJob", Blog::ScheduledJob)
      scheduled.perform_async
      scheduled.drain

      expect(runs).to be_empty
      expect(scheduled.jobs).to be_empty
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
