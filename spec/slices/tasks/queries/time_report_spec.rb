# frozen_string_literal: true

RSpec.describe Tasks::Queries::TimeReport do
  let(:from) { Date.new(2026, 3, 2) }
  let(:to) { Date.new(2026, 3, 8) }

  def at(day, hour, minute = 0) = Blog::TimeZone.local_time(2026, 3, day, hour, minute)

  def link(task, project)
    params = { other_kind: "project", other_id: project.id }
    Links::Slice["operations.link_records"].call("task", task.id, params).value!
  end

  def report(by, from: self.from, to: self.to) = Tasks::Slice["queries.time_report"].call(from:, to:, by:)

  def session(task, from, to) = create(:work_session, task_id: task.id, started_at: from, ended_at: to)

  def sums(by, **) = report(by, **).groups.to_h { [it.name, it.seconds] }

  def worked(task, *spans, total: nil)
    spans.each { |from, to| session(task, from, to) }
    seconds = total || spans.sum { |from, to| (to - from).to_i }
    Tasks::Slice["repos.task_repo"].update(task.id, worked_seconds: seconds)
    task
  end

  describe "grouped by project" do
    let(:site) { create(:project, name: "site") }
    let(:gem) { create(:project, name: "gem") }

    it "sums the in-range time of every task linked to each project" do
      link(worked(create(:task), [at(2, 9), at(2, 10)]), site)
      link(worked(create(:task), [at(3, 9), at(3, 9, 30)]), site)
      link(worked(create(:task), [at(4, 9), at(4, 9, 15)]), gem)

      expect(sums("project")).to eq("gem" => 900, "site" => 5400)
    end

    context "with a task linked to two projects" do
      let!(:both) { worked(create(:task), [at(2, 9), at(2, 10)]).tap { link(it, site) }.tap { link(it, gem) } }

      before { link(worked(create(:task), [at(3, 9), at(3, 9, 30)]), site) }

      it "counts it in both" do
        expect(sums("project")).to eq("gem" => 3600, "site" => 5400)
      end

      it "marks both groups shared" do
        expect(report("project").groups.map { [it.name, it.shared] }).to eq([["gem", true], ["site", true]])
      end

      it "marks only that task shared" do
        expect(report("project").groups.last.tasks.map { [it.id == both.id, it.shared] })
          .to eq([[true, true], [false, false]])
      end
    end

    it "leaves a group unshared when none of its tasks count elsewhere" do
      link(worked(create(:task), [at(2, 9), at(2, 10)]), site)

      expect(report("project").groups.first).to have_attributes(shared: false, key: site.id)
    end

    it "returns time on tasks with no project as its own group last", :aggregate_failures do
      link(worked(create(:task), [at(2, 9), at(2, 10)]), site)
      loose = worked(create(:task), [at(3, 9), at(3, 9, 30)])

      last = report("project").groups.last

      expect(last).to have_attributes(key: nil, name: nil, seconds: 1800, shared: false)
      expect(last.tasks.map(&:id)).to eq([loose.id])
    end
  end

  describe "grouped by tag" do
    it "sums the same sessions under each tag, with untagged time last" do
      worked(create(:task, tags: %w[ruby web]), [at(2, 9), at(2, 10)])
      worked(create(:task, tags: %w[ruby]), [at(3, 9), at(3, 9, 30)])
      worked(create(:task), [at(4, 9), at(4, 9, 15)])

      expect(report("tag").groups.map { [it.name, it.seconds, it.shared] })
        .to eq([["ruby", 5400, true], ["web", 3600, true], [nil, 900, false]])
    end
  end

  describe "grouped by day" do
    it "sums each day in the site's time zone" do
      worked(create(:task), [at(2, 22), at(3, 1)])
      worked(create(:task), [at(3, 9), at(3, 9, 30)])

      expect(sums("day")).to eq("2026-03-02" => 7200, "2026-03-03" => 5400)
    end

    it "keys each group by its date and marks nothing shared" do
      worked(create(:task), [at(2, 22), at(3, 1)])

      expect(report("day").groups.map { [it.key, it.shared] })
        .to eq([[Date.new(2026, 3, 2), false], [Date.new(2026, 3, 3), false]])
    end

    it "sums the same time as the project and tag groupings" do
      site = create(:project)
      link(worked(create(:task, tags: %w[ruby]), [at(2, 9), at(2, 10)]), site)
      worked(create(:task), [at(3, 9), at(3, 9, 30)])

      expect([sums("day"), sums("project"), sums("tag")].map { it.values.sum }).to eq([5400, 5400, 5400])
    end
  end

  it "counts only the part of a session inside the range", :aggregate_failures do
    task = worked(create(:task), [at(1, 23), at(2, 1)], [at(8, 23), at(9, 2)])

    found = report("day")

    expect(found.groups.to_h { [it.name, it.seconds] }).to eq("2026-03-02" => 3600, "2026-03-08" => 3600)
    expect(found.seconds).to eq(7200)
    expect(found.groups.first.tasks.map(&:id)).to eq([task.id])
  end

  it "counts a running session up to now" do
    task = create(:task, :in_progress)
    create(:work_session, task_id: task.id, started_at: Time.now - 600)
    today = Blog::TimeZone.today

    expect(report("day", from: today - 1, to: today).seconds).to be_within(5).of(600)
  end

  describe "a hand-set total" do
    it "spreads across the task's sessions by their length" do
      worked(create(:task), [at(2, 9), at(2, 10)], [at(3, 9), at(3, 12)], total: 2 * 3600)

      expect(sums("day")).to eq("2026-03-02" => 1800, "2026-03-03" => 5400)
    end

    it "spreads over sessions outside the range too" do
      worked(create(:task), [at(2, 9), at(2, 10)], [at(10, 9), at(10, 10)], total: 4 * 3600)

      expect(sums("day")).to eq("2026-03-02" => 7200)
    end

    it "lands on the day the task closed when it has no sessions" do
      task = create(:task, :done, completed_at: at(5, 15))
      worked(task, total: 2700)

      expect(sums("day")).to eq("2026-03-05" => 2700)
    end

    it "is left out when it has no sessions and the task never closed" do
      worked(create(:task), total: 2700)

      expect(report("day").groups).to be_empty
    end

    it "is left out when the task closed outside the range" do
      worked(create(:task, :done, completed_at: at(9, 15)), total: 2700)

      expect(report("day").groups).to be_empty
    end
  end

  it "lists each group's tasks with their time in the range, most first" do
    small = worked(create(:task, title: "small"), [at(2, 9), at(2, 9, 20)])
    big = worked(create(:task, title: "big"), [at(2, 10), at(2, 12)], [at(12, 10), at(12, 11)])

    expect(report("day").groups.first.tasks.map { [it.id, it.title, it.seconds] })
      .to eq([[big.id, "big", 7200], [small.id, "small", 1200]])
  end

  it "returns no groups for a range with no time" do
    expect(report("project")).to have_attributes(seconds: 0, groups: [], by: "project", from:, to:)
  end
end
