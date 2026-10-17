# frozen_string_literal: true

RSpec.describe Health::Repos::HealthQueries do
  let(:monday) { Date.new(2026, 9, 7) }
  let(:sunday) { monday + 13 }

  def compared(*groups)
    subject, rest = groups.map { |days, averages| Health::Structs::PatternGroup.new(days:, averages:) }

    Health::Structs::Pattern.new(subject:, rest:)
  end

  def health_day(offset, focus: nil, workout_at: nil, **)
    day = monday + offset
    create(:health_day, day:, **)
    create(:workout, started_at: at(day, workout_at)) if workout_at
    worked_minutes(day, focus) if focus
  end

  def night(asleep, hrv) = { minutes_asleep: asleep, hrv: }

  def report = described_class.new.report(from: monday, to: sunday)

  def worked(from, to)
    task = create(:task, :in_progress, worked_seconds: (to - from).to_i)
    create(:work_session, task_id: task.id, started_at: from, ended_at: to)
  end

  def worked_minutes(day, minutes) = worked(at(day, 9), at(day, 9) + (minutes * 60))

  describe "a day with health and work" do
    let(:tuesday) { monday + 1 }
    let(:figures) do
      {
        day: tuesday, minutes_asleep: 420, bed_at: at(monday, 23), woke_at: at(tuesday, 7), resting_heart_rate: 54,
        hrv: 48.5, steps: 8421, active_zone_minutes: 22, focus_minutes: 60, commits: 2, late_commits: 1,
        tasks_done: 1, pull_requests_opened: 1, pull_requests_merged: 1, journal_entries: 1,
        first_active_at: at(tuesday, 8, 30), last_active_at: at(tuesday, 22, 15),
      }
    end

    before do
      create(:health_day, day: tuesday, minutes_asleep: 420, bed_at: at(monday, 23), woke_at: at(tuesday, 7),
                          resting_heart_rate: 54, hrv: 48.5, steps: 8421, active_zone_minutes: 22)
      worked(at(tuesday, 9), at(tuesday, 10))
      create(:commit, commit_date: tuesday, commit_time: "08:30")
      create(:commit, commit_date: tuesday, commit_time: "22:15")
      create(:task, :done, completed_at: at(tuesday, 15))
      create(:task, :canceled, completed_at: at(tuesday, 16))
      create(:pull_request, ready_at: at(tuesday, 11))
      create(:pull_request, ready_at: at(monday, 11), merged_at: at(tuesday, 12))
      create(:journal_entry, entry_date: tuesday)
    end

    it "returns one row for each day of the range" do
      expect(report.days.map(&:day)).to eq((monday..sunday).to_a)
    end

    it "returns the day's health and work figures" do
      expect(report.days[1].to_h).to eq(figures)
    end
  end

  it "counts each minute of overlapping work sessions once" do
    worked(at(monday, 9), at(monday, 11))
    worked(at(monday, 10), at(monday, 12))

    expect(report.days.first).to have_attributes(
      focus_minutes: 180, first_active_at: at(monday, 9), last_active_at: at(monday, 12),
    )
  end

  it "counts no manual time for a task whose total fell below its sessions" do
    task = create(:task, :done, completed_at: at(monday + 8, 11), worked_seconds: 1800)
    create(:work_session, task_id: task.id, started_at: at(monday, 9), ended_at: at(monday, 11))
    create(:work_session, task_id: task.id, started_at: at(monday + 8, 9), ended_at: at(monday + 8, 10))

    expect(report.days.values_at(0, 8).map(&:focus_minutes)).to eq([120, 60])
  end

  it "splits a session that runs past midnight between its days" do
    worked(at(monday, 23), at(monday + 1, 1))

    expect(report.days.first(2).map { [it.focus_minutes, it.first_active_at, it.last_active_at] }).to eq(
      [[60, at(monday, 23), at(monday + 1, 0)], [60, at(monday + 1, 0), at(monday + 1, 1)]],
    )
  end

  it "returns the work of a day with no health data" do
    create(:commit, commit_date: monday)

    expect(report.days.first).to have_attributes(minutes_asleep: nil, hrv: nil, commits: 1, health?: false)
  end

  it "returns the 30 day baselines" do
    create(:health_day, day: sunday - 30, minutes_asleep: 100, hrv: 10.0, resting_heart_rate: 90)
    create(:health_day, day: sunday - 29, minutes_asleep: 400, hrv: 40.0, resting_heart_rate: 55)
    create(:health_day, day: sunday, minutes_asleep: 450, hrv: 45.0, resting_heart_rate: 56)

    expect(report.baseline).to eq(Health::Structs::Baseline.new(minutes_asleep: 425.0, hrv: 42.5,
                                                                resting_heart_rate: 55.5))
  end

  it "returns the range's workouts" do
    inside = create(:workout, started_at: at(sunday, 23))
    create(:workout, started_at: at(sunday + 1, 0, 30))

    expect(report.workouts.map(&:id)).to eq([inside.id])
  end

  it "compares focus after short weekday nights with the other weekdays" do
    { 0 => 60, 1 => 90, 2 => 30 }.each { |offset, focus| health_day(offset, focus:, minutes_asleep: 300) }
    { 3 => 240, 4 => 200, 7 => 280 }.each { |offset, focus| health_day(offset, focus:, minutes_asleep: 450) }
    health_day(5, minutes_asleep: 200)

    expect(report.patterns.short_nights).to eq(compared([3, { focus_minutes: 60.0 }], [3, { focus_minutes: 240.0 }]))
  end

  it "compares focus on weekday workout mornings with weekdays without a workout" do
    days = [[0, 7, 120], [1, 6, 100], [2, 8, 140], [8, 18, 300], [3, nil, 60], [4, nil, 50], [7, nil, 70]]
    days.each { |offset, hour, focus| health_day(offset, focus:, workout_at: hour, steps: 5000) }

    expect(report.patterns.morning_workouts).to eq(compared([3, { focus_minutes: 120.0 }],
                                                            [3, { focus_minutes: 60.0 }]))
  end

  it "compares the night after late commits with the other nights" do
    [0, 2, 4].each { create(:commit, commit_date: monday + it, commit_time: "22:30") }
    [1, 3, 5].each { health_day(it, minutes_asleep: 300, hrv: 30.0) }
    [7, 8, 9].each { health_day(it, minutes_asleep: 450, hrv: 50.0) }

    expect(report.patterns.late_commits).to eq(compared([3, night(300.0, 30.0)], [3, night(450.0, 50.0)]))
  end

  it "compares the last 7 days of resting heart rate with the days before" do
    (7..13).each { health_day(it, resting_heart_rate: 58) }
    (0..2).each { health_day(it, resting_heart_rate: 54) }

    expect(report.patterns.resting_heart_rate).to eq(
      compared([7, { resting_heart_rate: 58.0 }], [3, { resting_heart_rate: 54.0 }]),
    )
  end

  it "returns no pattern when a group has under 3 days" do
    { 0 => 300, 1 => 300, 2 => 450, 3 => 450, 4 => 450 }.each do |offset, asleep|
      health_day(offset, minutes_asleep: asleep, resting_heart_rate: 55)
    end
    [0, 2].each { create(:commit, commit_date: monday + it, commit_time: "23:00") }

    expect(report.patterns.to_h.values).to all(be_nil)
  end
end
