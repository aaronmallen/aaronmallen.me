Feature: Link check MCP tools
  An agent queues the checks the admin queues: one short link, one post's links, or the whole nightly run.

  Background:
    Given I am signed in to the admin
    And an MCP client connected with the scopes "read write"

  Scenario: check_short_link queues a check of the destination
    Given these short links:
      | code | destination              |
      | dead | http://203.0.113.30/gone |
    And the web answers GET "http://203.0.113.30/gone" with status 404
    When I call the MCP tool "check_short_link" with:
      """
      {"id": 1}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "status": "queued"}
      """
    And the short_link_checks table has a row with:
      | short_link_id | failures | reason        |
      | 1             | 1        | 404 Not Found |

  Scenario: check_post_links queues a check of every link in the post, or the one link given
    Given a published post "Notes" that links to:
      """
      http://203.0.113.30/gone
      http://203.0.113.31/other
      """
    And the web answers GET "http://203.0.113.30/gone" with status 404
    When I call the MCP tool "check_post_links" with:
      """
      {"id": 1, "url": "http://203.0.113.30/gone"}
      """
    Then the MCP answer holds:
      """
      {"id": 1, "status": "queued"}
      """
    And the post_link_checks table has a row with:
      | url                      | failures |
      | http://203.0.113.30/gone | 1        |
    And the post_link_checks table holds 1 rows
    Given the web answers GET "http://203.0.113.31/other" with status 200
    When I call the MCP tool "check_post_links" with:
      """
      {"id": 1}
      """
    Then the post_link_checks table has a row with:
      | url                      | failures |
      | http://203.0.113.30/gone | 2        |
    And the post_link_checks table holds 2 rows

  Scenario Outline: A link check tool refuses what it cannot check
    Given a draft post "Draft" that links to:
      """
      http://203.0.113.30/gone
      """
    When I call the MCP tool "<tool>" with:
      """
      <call>
      """
    Then the MCP tool refuses with "<message>"

    Examples:
      | tool             | call           | message                                 |
      | check_short_link | {"id": 999999} | no short link has the ID 999999         |
      | check_post_links | {"id": 1}      | no published blog post has the ID 1     |

  Scenario: run_link_check queues a new run and answers when it was queued
    Given a published post "Notes" that links to:
      """
      http://203.0.113.30/fine
      """
    And the web answers GET "http://203.0.113.30/fine" with status 200
    When I call the MCP tool "run_link_check"
    Then the MCP answer holds:
      """
      {"status": "queued"}
      """
    And the link_check_runs table has a row with:
      | links_checked | links_due | finished_at |
      | 1             | 1         | set         |

  Scenario Outline: A link check tool says so when the job queue is down
    Given these short links:
      | code | destination              |
      | dead | http://203.0.113.30/gone |
    And a published post "Notes" that links to:
      """
      http://203.0.113.30/gone
      """
    And Redis goes down
    When I call the MCP tool "<tool>" with:
      """
      <call>
      """
    Then the MCP tool refuses with "the job queue is down, so nothing was queued; try again soon"

    Examples:
      | tool             | call      |
      | check_short_link | {"id": 1} |
      | check_post_links | {"id": 1} |
      | run_link_check   | {}        |
