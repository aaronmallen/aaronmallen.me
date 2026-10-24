Feature: Refreshing project stars and releases from GitHub
  Saving a project with a new repo queues a fetch of its stars and latest release, and a nightly run refreshes
  every project that names a repo. A failed answer keeps what the project held.

  Background:
    Given I am signed in to the admin
    And GitHub holds a token for the issue sync
    And GitHub reports "aaronmallen/sai" with 42 stars and the release "v1.0.0"

  Scenario: Saving a new project with a repo fetches its stars and release
    When I save a project in the admin
    And the queued project refreshes run
    Then the project "sai" holds 42 stars and the release "v1.0.0"

  Scenario: Saving a project fetches only when the repo is new or changes
    Given the projects:
      | name  | repo             | stars |
      | plain |                  | 0     |
      | kept  | aaronmallen/kept | 5     |
      | moved | aaronmallen/old  | 0     |
    When I save a project in the admin with:
      | project       | plain |
      | project[name] | plain |
      | project[repo] |       |
    And I save a project in the admin with:
      | project       | kept             |
      | project[name] | kept             |
      | project[repo] | aaronmallen/kept |
    And I save a project in the admin with:
      | project       | moved           |
      | project[name] | moved           |
      | project[repo] | aaronmallen/sai |
    And the queued project refreshes run
    Then GitHub was asked for "aaronmallen/kept" 0 times
    And GitHub was asked for "aaronmallen/sai" 1 time
    And the project "moved" holds 42 stars and the release "v1.0.0"
    And the project "kept" holds 5 stars and the release "none"

  Scenario: A fetch keeps the stars when GitHub fails, and asks nothing for a project with no repo
    Given the projects:
      | name  | repo              | stars |
      | fresh | aaronmallen/fresh | 0     |
      | loose |                   | 0     |
    And the sync "projects" failed with "rate_limited"
    And GitHub answers the REST path "aaronmallen/fresh" with status 502
    When the project refresh for "fresh" runs
    And the project refresh for "loose" runs
    Then the project "fresh" holds 0 stars and the release "none"
    And the sync failure of "projects" is "rate_limited"
    And GitHub was asked for "aaronmallen/fresh" 1 time

  Scenario: The nightly refresh stores what GitHub reports for every project that names a repo
    Given the projects:
      | name     | repo                       | stars | release | url                          | archived  | started    |
      | site     | aaronmallen/aaronmallen.me | 3     | v1.0.0  |                              |           |            |
      | other    | aaronmallen/other          | 0     |         | https://gest.aaronmallen.dev |           |            |
      | gone     | aaronmallen/gone           | 1     |         |                              | today - 1 | today - 30 |
      | current  | aaronmallen/current        | 7     | v3.1.0  |                              |           |            |
      | loose    |                            | 5     |         |                              |           |            |
    And GitHub reports "aaronmallen/aaronmallen.me" with 42 stars and the release "v2.0.0"
    And GitHub reports "aaronmallen/other" with 9 stars and the release "v3.1.0"
    And GitHub reports "aaronmallen/gone" with 7 stars and the release "v3.1.0"
    And GitHub reports "aaronmallen/current" with 7 stars and the release "v3.1.0"
    And the project "current" last changed a day ago
    And the project "loose" last changed a day ago
    And the sync "projects" failed with "rate_limited"
    When the nightly project refresh runs
    Then the project "site" holds 42 stars and the release "v2.0.0"
    And the project "other" holds 9 stars and the release "v3.1.0"
    And the project "gone" holds 7 stars and the release "v3.1.0"
    And the project "current" has not changed since
    And the project "loose" holds 5 stars and the release "none"
    And the project "loose" has not changed since
    And no sync failure of "projects" is left

  Scenario: The nightly refresh clears the release of a repo with none
    Given the projects:
      | name | repo                       | stars | release |
      | site | aaronmallen/aaronmallen.me | 3     | v1.0.0  |
    And GitHub answers the REST path "aaronmallen/aaronmallen.me" with:
      """
      { "full_name": "aaronmallen/aaronmallen.me", "stargazers_count": 42 }
      """
    When the nightly project refresh runs
    Then the project "site" holds 42 stars and the release "none"

  Scenario: The nightly refresh keeps a repo GitHub cannot find and refreshes the others
    Given the projects:
      | name  | repo                       | stars | release |
      | site  | aaronmallen/aaronmallen.me | 3     | v1.0.0  |
      | other | aaronmallen/other          | 0     |         |
    And GitHub reports "aaronmallen/other" with 7 stars and the release "v3.1.0"
    When the nightly project refresh runs
    Then the project "site" holds 3 stars and the release "v1.0.0"
    And GitHub was asked for "aaronmallen/aaronmallen.me/releases/latest" 0 times
    And the project "other" holds 7 stars and the release "v3.1.0"

  Scenario: The nightly refresh keeps what a project held when GitHub answers a page that isn't JSON
    Given the projects:
      | name | repo                       | stars | release |
      | site | aaronmallen/aaronmallen.me | 3     | v1.0.0  |
    And GitHub answers the REST path "aaronmallen/aaronmallen.me" with a page that isn't JSON
    And GitHub answers the REST path "aaronmallen/aaronmallen.me/releases/latest" with a page that isn't JSON
    When the nightly project refresh runs
    Then the project "site" holds 3 stars and the release "v1.0.0"
    And no sync failure of "projects" is left

  Scenario: The nightly refresh asks nothing with GitHub not connected, and records that it never ran
    Given the database runs:
      """
      DELETE FROM service_connections WHERE provider = 'github';
      """
    And the projects:
      | name | repo                       | stars |
      | site | aaronmallen/aaronmallen.me | 3     |
    And the sync "projects" failed with "rate_limited"
    When the nightly project refresh runs
    Then GitHub was asked for no repo
    And the sync failure of "projects" is "not_configured"

  Scenario: The nightly refresh records a rate limit and keeps the stars
    Given the projects:
      | name | repo                       | stars | release |
      | site | aaronmallen/aaronmallen.me | 3     | v1.0.0  |
    And GitHub rate limits the REST path "aaronmallen/aaronmallen.me"
    When the nightly project refresh runs
    Then the sync failure of "projects" is "rate_limited"
    And the project "site" holds 3 stars and the release "v1.0.0"

  Scenario: The nightly refresh records what GitHub answered and keeps what it refreshed before the error
    Given the projects:
      | name  | repo                       | stars |
      | site  | aaronmallen/aaronmallen.me | 3     |
      | other | aaronmallen/other          | 0     |
    And GitHub reports "aaronmallen/aaronmallen.me" with 42 stars and the release "v2.0.0"
    And GitHub answers the REST path "aaronmallen/other" with status 502
    When the nightly project refresh runs
    Then the sync failure of "projects" is "github_failed" with a message holding "GitHub answered 502 for /repos/aaronmallen/other"
    And the project "site" holds 42 stars and the release "v2.0.0"

  @timeout:120_000
  Scenario: The nightly refresh records a connection that timed out
    Given the projects:
      | name | repo                       | stars |
      | site | aaronmallen/aaronmallen.me | 3     |
    And GitHub answers the REST path "aaronmallen/aaronmallen.me" after the client gives up
    When the nightly project refresh runs
    Then the sync failure of "projects" is "github_failed" with a message holding "GitHub request to /repos/aaronmallen/aaronmallen.me failed: "
    And the project "site" holds 3 stars and the release "none"
