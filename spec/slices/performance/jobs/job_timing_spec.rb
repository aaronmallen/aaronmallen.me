# frozen_string_literal: true

RSpec.describe "Timing a Sidekiq job", type: :app do
  let(:job) do
    stub_const("Spec::TimedJob", Class.new(Blog::Job) do
      def perform(fail)
        Performance::Slice["db.rom"].relations[:performance_jobs].count
        raise ArgumentError, "boom" if fail
      end
    end)
  end

  def rows = Performance::Slice["db.rom"].relations[:performance_jobs].to_a

  def run(fail: false)
    job.perform_async(fail)
    job.drain
  end

  def run_failing
    run(fail: true)
  rescue ArgumentError
    nil
  end

  before do
    record = ->(**row) { Performance::Slice["operations.record_timing"].call(:job, **row) }
    Sidekiq::Testing.server_middleware { it.add Blog::JobTimer, record }
  end

  after { Sidekiq::Testing.server_middleware { it.remove Blog::JobTimer } }

  it "stores the job's class, outcome and queries when it finishes" do
    run

    expect(rows).to contain_exactly(include(job: "Spec::TimedJob", outcome: "succeeded", query_count: 1))
  end

  it "stores how long the job and its queries took" do
    run

    expect(rows.first).to include(duration: be_positive, query_time: be >= 0)
  end

  it "stores no error when the job finishes" do
    run

    expect(rows.first).to include(error_class: nil, error_message: nil)
  end

  context "when the job fails" do
    it "lets the error through" do
      expect { run(fail: true) }.to raise_error(ArgumentError)
    end

    it "stores a failed outcome" do
      run_failing

      expect(rows).to contain_exactly(include(job: "Spec::TimedJob", outcome: "failed", query_count: 1))
    end

    it "stores the error's class and message" do
      run_failing

      expect(rows.first).to include(error_class: "ArgumentError", error_message: "boom")
    end
  end

  context "when the row fails to write" do
    before do
      repo = Object.new.tap { |stub| stub.define_singleton_method(:record_job) { |**| raise IOError } }
      replace_component("repos.timing_mutations", repo)
    end

    it "lets the job finish" do
      expect { run }.not_to raise_error
    end
  end
end
