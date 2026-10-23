Feature: Development seeds
  mise run db:seed fills every admin area in development, and a second run adds nothing.

  @timeout:300_000
  Scenario: The development seeds fill every admin area
    When I seed the database as development
    Then it succeeds
    And each of these tables holds a row:
      | table                |
      | posts                |
      | memory_files         |
      | memory_facts         |
      | agent_sessions       |
      | artifacts            |
      | artifact_versions    |
      | decisions            |
      | decision_options     |
      | decision_comments    |
      | calendars            |
      | calendar_events      |
      | share_group_files    |
      | share_groups         |
      | short_links          |
      | sign_ins             |
      | devices              |
      | known_devices        |
      | sightings            |
      | mail_accounts        |
      | mail_threads         |
      | mail_messages        |
      | saved_views          |
      | health_days          |
      | workouts             |
      | performance_requests |
      | performance_pages    |
      | performance_jobs     |
      | performance_rollups  |
      | work_sessions        |
      | notes                |
      | note_folders         |
      | note_links           |
      | people               |
    And the database answers "true, true" for:
      """
      select
        exists (select 1 from sign_ins where dismissed_at is not null) as dismissed,
        exists (select 1 from people where jsonb_array_length(emails) > 0) as emailed
      """

  @timeout:300_000
  Scenario: A second run of the development seeds adds nothing
    When I seed the database as development
    And I count the rows in every table
    And I seed the database as development
    Then it succeeds
    And every table holds the rows it did
