Feature: A short link on the share host
  A short link sends whoever follows it on to its destination and counts the people who click.

  Background:
    Given the short link "talk" to "https://example.com/talk"

  Scenario: A short link sends a browser on, counts the click and stamps when, and no cache keeps the answer
    When a browser fetches "/talk" from the share host
    Then the share host answers 302
    And the share host header "Location" is "https://example.com/talk"
    And the share host header "Cache-Control" is "private, no-store"
    And the short link to "https://example.com/talk" counts 1 click
    And the short link to "https://example.com/talk" has a last click time

  Scenario: A link pointed somewhere new sends people to the new place
    Given an API token
    When I PATCH "/short_links/1" through the API with:
      """
      {"destination": "https://example.org"}
      """
    And a browser fetches "/talk" from the share host
    Then the share host header "Location" is "https://example.org"

  Scenario: A link keeps its retarget time empty when its destination stays the same
    Given an API token
    When I PATCH "/short_links/1" through the API with:
      """
      {"destination": "https://example.com/talk"}
      """
    Then the API answers 200
    And the short link to "https://example.com/talk" has no retarget time

  Scenario: A link made under an older, longer code still sends people on
    Given the short link "ab2cdefghjkmnpqr" to "https://example.com/old"
    When a browser fetches "/ab2cdefghjkmnpqr" from the share host
    Then the share host header "Location" is "https://example.com/old"

  Scenario: A prefix of the code answers 404 and counts no click
    When a browser fetches "/tal" from the share host
    Then the share host answers 404
    And the short link to "https://example.com/talk" counts 0 clicks

  Scenario: A changed code ends the old link and the new one sends people on
    Given an API token
    When I PATCH "/short_links/1" through the API with:
      """
      {"code": "talk-now"}
      """
    And I fetch "/talk" from the share host
    Then the share host answers 404
    And the share host header "Cache-Control" is "private, no-store"
    When I fetch "/talk-now" from the share host
    Then the share host answers 302

  Scenario: A deleted link answers 404
    Given the short link to "https://example.com/talk" is deleted
    When I fetch "/talk" from the share host
    Then the share host answers 404

  Scenario Outline: A fetch by <who> sends it on but counts no click
    When the agent "<agent>" fetches "/talk" from the share host
    Then the share host answers 302
    And the short link to "https://example.com/talk" counts 0 clicks
    And the short link to "https://example.com/talk" has no last click time

    Examples:
      | who                  | agent                                                         |
      | Slack                | Slackbot-LinkExpanding 1.0 (+https://api.slack.com/robots)    |
      | curl                 | curl/8.4.0                                                    |
      | Mastodon             | http.rb/5.2.0 (Mastodon/4.3.0; +https://mastodon.example/)    |
      | Pleroma              | Pleroma 2.7.0; https://pleroma.example                        |
      | Akkoma               | Akkoma 3.13.2; https://akkoma.example                         |
      | Misskey              | Misskey/2024.10.1 (https://misskey.example)                   |
      | Bluesky              | Mozilla/5.0 (compatible; Cardyb/1.1)                          |
      | the link check       | aaronmallen.me link-check (+https://aaronmallen.me)           |
      | the link title fetch | aaronmallen.me link-title (+https://aaronmallen.me)           |
      | the webmention fetch | aaronmallen.me webmention (+https://aaronmallen.me)           |
      | no browser           |                                                               |

  Scenario: A head request counts no click
    When a browser asks the share host for the head of "/talk"
    Then the short link to "https://example.com/talk" counts 0 clicks

  Scenario: The blog's host leaves the short link's code alone
    When I fetch "/talk" from the blog host
    Then the share host answers 404
