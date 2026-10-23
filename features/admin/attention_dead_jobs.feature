Feature: Dead jobs on the attention list
  A background job that runs out of retries lands on the Needs attention card, newest first, where the owner can
  retry it or throw it away. The API and list_attention list them too.

  Background:
    Given I am signed in to the admin
    And the country database holds the test networks
    And an API token

  Scenario: A job that died shows on the card with its name, when it died and its error
    Given the dead job "Social::Jobs::SendWebmention" died 60 minutes ago with the error "the target refused it"
    When I visit "/admin"
    Then the attention row "Social::Jobs::SendWebmention" ends with "· RuntimeError: the target refused it"
    And the attention row "Social::Jobs::SendWebmention" gives the time the job died

  Scenario: list_attention returns a dead job with its error marked untrusted
    Given the dead job "Social::Jobs::SendWebmention" died at "2026-01-07T15:30:00Z" with the error "the target refused it"
    And an MCP client connected with the scopes "read"
    When I call the MCP tool "list_attention"
    Then the answer's "dead_jobs" is:
      """
      [{"name": "Social::Jobs::SendWebmention", "died_at": "2026-01-07T15:30:00Z", "error": "RuntimeError: the target refused it"}]
      """
    And the answer includes '"untrusted":true'
    And the MCP tool "list_attention" answers what "GET /api/v1/attention" answers

  Scenario: The card offers Retry and Discard against the jobs tab's dead set and comes back to Today
    Given the dead job "Social::Jobs::SendWebmention" died 1 minute ago
    When I visit "/admin"
    Then the attention row "Social::Jobs::SendWebmention" posts "return_to=/admin" to:
      """
      /admin/settings/jobs/dead/<jid>/retry
      /admin/settings/jobs/dead/<jid>/discard
      """
    And the "Discard" button on the attention row "Social::Jobs::SendWebmention" shows a trash can
    And the attention row "Social::Jobs::SendWebmention" names "Social::Jobs::SendWebmention" before "Discard"

  Scenario: Retrying a job from the card queues it again and takes it off the card
    Given the dead job "Social::Jobs::SendWebmention" from the queue "held" died 1 minute ago
    When I visit "/admin"
    And I send the "Retry" form on the attention row "Social::Jobs::SendWebmention"
    Then the Today page sends me to "/admin"
    And the dead job is back on the "held" queue
    And the attention card is not shown

  Scenario: Discarding a job from the card deletes it and takes it off the card
    Given the dead job "Social::Jobs::SendWebmention" from the queue "held" died 1 minute ago
    When I visit "/admin"
    And I send the "Discard" form on the attention row "Social::Jobs::SendWebmention"
    Then the dead job set is empty
    And the job queue "held" is empty
    And the attention card is not shown

  Scenario: The card opens the jobs tab's menu for the row, which copies its error
    Given the dead job "Social::Jobs::SendWebmention" died 1 minute ago
    When I visit "/admin"
    Then the attention row "Social::Jobs::SendWebmention" has the menu of the dead job
    When I open the menu of the attention row "Social::Jobs::SendWebmention"
    Then the dead job menu offers "Retry now, Copy error, Discard"
    And the dead job menu copies "RuntimeError: boom"

  Scenario: The card lists the newest death first
    Given the dead job "Posts::Jobs::Older" died 120 minutes ago
    And the dead job "Posts::Jobs::Newer" died 1 minute ago
    When I visit "/admin"
    Then the attention card lists:
      """
      Posts::Jobs::Newer
      Posts::Jobs::Older
      """

  Scenario: A job still retrying stays off the card
    Given the job "Posts::Jobs::Retrying" waits to retry
    When I visit "/admin"
    Then the attention card is not shown

  Scenario: The card shows a commit sync failure once, beside the dead backfill for another repository
    Given these sync failures:
      | sync    | repo            | reason        |
      | commits | aaronmallen/one | github_failed |
    And the dead commit backfill for "aaronmallen/one" died 1 minute ago
    And the dead commit backfill for "aaronmallen/two" died 2 minutes ago
    When I visit "/admin"
    Then the Today page shows 1 sync failure
    And the attention card lists:
      """
      Record::Jobs::BackfillRepoCommits
      """
    When I call the API with "GET /api/v1/attention"
    Then the answer's "dead_jobs" lists 2
    Given an MCP client connected with the scopes "read"
    When I call the MCP tool "list_attention"
    Then the answer's "dead_jobs" lists 2

  Scenario: The card shows the newest five dead jobs and links to the rest
    Given the dead job "Posts::Jobs::Job0" died 0 minutes ago
    And the dead job "Posts::Jobs::Job1" died 1 minute ago
    And the dead job "Posts::Jobs::Job2" died 2 minutes ago
    And the dead job "Posts::Jobs::Job3" died 3 minutes ago
    And the dead job "Posts::Jobs::Job4" died 4 minutes ago
    And the dead job "Posts::Jobs::Job5" died 5 minutes ago
    And the dead job "Posts::Jobs::Job6" died 6 minutes ago
    When I visit "/admin"
    Then the attention card lists:
      """
      Posts::Jobs::Job0
      Posts::Jobs::Job1
      Posts::Jobs::Job2
      Posts::Jobs::Job3
      Posts::Jobs::Job4
      """
    And the Today line "Dead jobs" reads "2 more →"
    And the Today line "Dead jobs" links to "/admin/settings/jobs?set=dead#jobs-dead"
    When I call the API with "GET /api/v1/attention"
    Then the answer matches:
      """
      {"dead_jobs": [{"name": "Posts::Jobs::Job0"}, {"name": "Posts::Jobs::Job1"}, {"name": "Posts::Jobs::Job2"},
                      {"name": "Posts::Jobs::Job3"}, {"name": "Posts::Jobs::Job4"}],
        "dead_job_count": 7}
      """
    Given an MCP client connected with the scopes "read"
    When I call the MCP tool "list_attention"
    Then the answer matches:
      """
      {"dead_jobs": [{"name": "Posts::Jobs::Job0"}, {"name": "Posts::Jobs::Job1"}, {"name": "Posts::Jobs::Job2"},
                      {"name": "Posts::Jobs::Job3"}, {"name": "Posts::Jobs::Job4"}],
        "dead_job_count": 7}
      """

  Scenario: The API lists no dead jobs while Redis is down
    Given the dead job "Posts::Jobs::Job0" died 1 minute ago
    When Redis goes down
    And I call the API with "GET /api/v1/attention"
    Then the call answers 200
    And the answer's "dead_jobs" is:
      """
      []
      """
    And the answer's "dead_job_count" is "0"
