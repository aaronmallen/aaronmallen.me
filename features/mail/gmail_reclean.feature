Feature: Cleaning stored Gmail HTML again
  The reclean job fetches each stored Gmail thread again and rewrites its HTML under the current
  rules, a page at a time, half a minute apart.

  Background:
    Given the Google account "aaron@example.com" is connected with "openid gmail.modify"
    And the mail account "aaron@example.com"
    And the mail threads:
      | subject | account           | gmail id | message gmail id | html                |
      | One     | aaron@example.com | t1       | mt1              | <p id="nav">Old</p> |
      | Two     | aaron@example.com | t2       | mt2              | <p id="nav">Old</p> |
    And I am signed in to the admin

  Scenario Outline: The reclean rewrites each stored message's HTML: <case>
    Given Gmail holds the thread "t1" with the messages:
      | id  | html   |
      | mt1 | <html> |
    And Gmail holds the thread "t2" with the messages:
      | id  | html       |
      | mt2 | <p>Two</p> |
    When the stored mail HTML is cleaned again
    Then the Gmail thread "t1" has the messages:
      | html_body  |
      | <p>One</p> |
    And the Gmail thread "t2" has the messages:
      | html_body  |
      | <p>Two</p> |

    Examples:
      | case                 | html                                              |
      | it strips script     | <p id="x">One<script>x()</script></p>             |
      | it strips transforms | <p style="transform: translateY(-90vh)">One</p>   |

  Scenario: The reclean leaves a thread Gmail no longer has as it is
    Given Gmail answers GET "/users/me/threads/t1" with status 404
    And Gmail holds the thread "t2" with the messages:
      | id  | html       |
      | mt2 | <p>Two</p> |
    When the stored mail HTML is cleaned again
    Then the Gmail thread "t1" has the messages:
      | html_body           |
      | <p id="nav">Old</p> |
    And the Gmail thread "t2" has the messages:
      | html_body  |
      | <p>Two</p> |

  Scenario: The reclean queues the threads after the last one it cleaned half a minute out
    Given Gmail holds the thread "t1" with the messages:
      | id  |
      | mt1 |
    And Gmail holds the thread "t2" with the messages:
      | id  |
      | mt2 |
    When the stored mail HTML is cleaned again
    Then the jobs page lists "Mail::Jobs::RecleanMailHtml" with "2,0" in about 30 seconds
    And the page has no axe breaches in light or dark

  Scenario: The reclean queues the same threads again in two minutes when Gmail rate limits it
    Given Gmail rate limits GET "/users/me/threads/t1" with status 429
    When the stored mail HTML is cleaned again after 0 with 2 gone
    Then the jobs page lists "Mail::Jobs::RecleanMailHtml" with "0,2" in about 120 seconds
