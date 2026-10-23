Feature: Pruning access records
  A nightly job drops sign-ins and sightings older than 90 days and devices unseen for 400.

  Scenario: The job keeps 90 days of sign-ins and sightings, every known device, and devices seen in 400 days
    Given an MCP client "Claude" with a live token
    And the table sign_ins holds:
      | outcome   | provider | address     | user_agent | city  | created_at   | dismissed_at |
      | signed_in | github   | 81.2.69.160 | Chrome/141 | Old   | 91 days ago  |              |
      | signed_in | github   | 81.2.69.160 | Chrome/141 | New   | 89 days ago  |              |
      | denied    | github   | 81.2.69.160 | Chrome/141 | Gone  | 91 days ago  | 20 days ago  |
      | denied    | github   | 81.2.69.160 | Chrome/141 | Kept  | 30 days ago  | 20 days ago  |
      | signed_in | github   | 81.2.69.160 | Chrome/141 | Long  | 400 days ago |              |
    And the table sightings holds:
      | oauth_client_id                | browser | city   | last_address | last_user_agent | first_seen_at | last_seen_at |
      | (SELECT id FROM oauth_clients) | Firefox | Stale  | 81.2.69.160  | Firefox/141     | 200 days ago  | 91 days ago  |
      | (SELECT id FROM oauth_clients) | Chrome  | London | 81.2.69.160  | Chrome/141      | 200 days ago  | 1 day ago    |
    And the table known_devices holds:
      | browser | os    | city   | country | created_at   |
      | Chrome  | macOS | London | GB      | 400 days ago |
    And the table devices holds:
      | browser | last_signed_in_at |
      | Old     | 401 days ago      |
      | New     | 399 days ago      |
    When the job "Security::Jobs::PruneAccessRecords" runs
    Then the database soon answers "Kept, New" for:
      """
      SELECT string_agg(city, ', ' ORDER BY city) FROM sign_ins
      """
    And the database answers "London" for:
      """
      SELECT string_agg(city, ', ') FROM sightings
      """
    And the database answers "London" for:
      """
      SELECT string_agg(city, ', ') FROM known_devices
      """
    And the database answers "New" for:
      """
      SELECT string_agg(browser, ', ') FROM devices
      """
