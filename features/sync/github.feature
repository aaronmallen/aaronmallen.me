Feature: The GitHub issue sync
  The sync imports the open issues assigned to me as tasks on the external list, keeps them in step with GitHub,
  and closes, cancels or reopens them as their issues change.

  Background:
    Given GitHub holds a token for the issue sync

  Scenario: A new issue assigned to me becomes one unseen task on the external list
    Given GitHub assigns me the issues:
      | number | title        | body            |
      | 7      | Sync my work | Keep it in step |
    When the GitHub issue sync runs twice
    Then the task from the issue "I_7" reads:
      | title  | Sync my work                                        |
      | note   | Keep it in step                                     |
      | list   | external                                            |
      | sprint |                                                     |
      | status | open                                                |
      | tags   |                                                     |
      | url    | https://github.com/aaronmallen/aaronmallen.me/issues/7 |
      | seen   | false                                               |
    And 1 tasks come from GitHub
    And GitHub's issue search asked for "is:issue is:open assignee:@me"
    And the GitHub issue sync records no failure

  Scenario: A run clears the failure the last run left
    Given GitHub assigns me the issues:
      | number |
      | 7      |
    And GitHub rate limits the next issue search
    When the GitHub issue sync runs
    Then the GitHub issue sync records the failure "rate_limited"
    And no task comes from the issue "I_7"
    When the GitHub issue sync runs
    Then the GitHub issue sync records no failure

  Scenario: The sync reads every page of assigned issues
    Given GitHub assigns me 12 issues
    And GitHub's search answers 1 issues a page
    When the GitHub issue sync runs
    Then GitHub was searched 12 times
    And 12 tasks come from GitHub
    And the GitHub issue sync records no failure

  Scenario: The sync stops when the next page cursor never moves
    Given GitHub's search keeps sending the same next page
    When the GitHub issue sync runs
    Then GitHub was searched 2 times
    And the GitHub issue sync records the failure "page_limit"

  Scenario: A search result that is not an issue is skipped while the rest import
    Given GitHub answers the next issue search with:
      """
      {"data": {"rateLimit": {"limit": 5000, "remaining": 4999, "resetAt": "2030-01-01T00:00:00Z"},
        "search": {"nodes": [{}, {"id": "I_7", "number": 7, "url": "https://github.com/aaronmallen/aaronmallen.me/issues/7",
          "title": "Sync my issues", "body": "", "state": "OPEN", "stateReason": null,
          "repository": {"nameWithOwner": "aaronmallen/aaronmallen.me"},
          "assignees": {"nodes": [{"id": "MDQ6VXNlcjkzMTA5NA=="}]}, "comments": {"pageInfo": {"hasNextPage": false}, "nodes": []},
          "labels": {"nodes": []}, "blockedBy": {"pageInfo": {"hasNextPage": false}, "nodes": []},
          "blocking": {"pageInfo": {"hasNextPage": false}, "nodes": []}, "parent": null,
          "subIssues": {"pageInfo": {"hasNextPage": false}, "nodes": []}}],
          "pageInfo": {"endCursor": null, "hasNextPage": false}},
        "viewer": {"id": "MDQ6VXNlcjkzMTA5NA=="}}}
      """
    When the GitHub issue sync runs
    Then the synced issues are "I_7"

  Scenario: Labels become the private tags they name, and no others
    Given the private tags "bug-fix, needs-review, github"
    And the tags table holds the rows:
      | name     | color   | scope  |
      | area-api | mk-blue | public |
    And GitHub assigns me the issues:
      | number | labels                                    |
      | 1      | Bug Fix, needs review, BugFix             |
      | 2      | area/api, Someday                         |
      | 3      | GitHub                                    |
      | 4      | !!!                                       |
    When the GitHub issue sync runs
    Then the task from the issue "I_1" reads:
      | tags | bug-fix, needs-review |
      | seen | false                 |
    And the task from the issue "I_2" reads:
      | tags |  |
    And the task from the issue "I_3" reads:
      | tags | github |
    And the task from the issue "I_4" reads:
      | tags   |      |
      | status | open |
    And the database soon holds "4" for:
      """
      SELECT count(*) FROM tags
      """

  Scenario: A tag I removed stays off, and a label added later adds no tag
    Given the private tags "bug-fix"
    And GitHub assigns me the issues:
      | number | labels  |
      | 1      | Bug Fix |
      | 2      |         |
    When the GitHub issue sync runs
    And the database runs:
      """
      DELETE FROM task_tags
      """
    And GitHub assigns me the issues:
      | number | labels  |
      | 1      | Bug Fix |
      | 2      | Bug Fix |
    And the GitHub issue sync runs
    Then the task from the issue "I_1" reads:
      | tags |  |
    And the task from the issue "I_2" reads:
      | tags |  |

  Scenario: An issue filed into a project takes its labels as the project's tags, made there when missing
    Given an API token
    And the projects:
      | name | key |
      | Pod  | POD |
    And the private tags "bug-fix"
    And the project "Pod" holds the tag "needs-review"
    And the saved task rules:
      | pattern       | projects |
      | aaronmallen/* | Pod      |
    And GitHub assigns me the issues:
      | number | labels                |
      | 1      | Bug Fix, needs review |
      | 2      |                       |
      | 3      | Bug Fix               |
    When the GitHub issue sync runs
    And GitHub assigns me the issues:
      | number | labels  |
      | 1      | Bug Fix, needs review |
      | 2      | Bug Fix |
      | 3      |         |
    And the GitHub issue sync runs
    Then the task from the issue "I_1" reads:
      | tags    | bug-fix@POD, needs-review@POD |
      | project | Pod                           |
    And the task from the issue "I_2" reads:
      | tags | bug-fix@POD |
    And the task events from the issue "I_2" read "tagged bug-fix"
    And the task from the issue "I_3" reads:
      | tags | bug-fix@POD |

  Scenario: Rules tag a new issue from a repo they match, once each, whatever its case
    Given an API token
    And the private tags "bug-fix"
    And the saved task rules:
      | pattern                    | tags          | provider |
      | aaronmallen/aaronmallen.me | ruby, hanami  | github   |
      | aaronmallen/*              | projects, ruby | github  |
      | aaronmallen/*              | linear        | linear   |
    And GitHub assigns me the issues:
      | number | labels  | repo                       |
      | 1      | Bug Fix | aaronmallen/aaronmallen.me |
      | 2      | Ruby    | AaronMallen/AaronMallen.me |
      | 3      |         | octocat/aaronmallen.me     |
    When the GitHub issue sync runs
    Then the task from the issue "I_1" reads:
      | tags | bug-fix, hanami, projects, ruby |
    And the task from the issue "I_2" reads:
      | tags | hanami, projects, ruby |
    And the task events from the issue "I_2" read "tagged hanami, tagged projects, tagged ruby"
    And the task from the issue "I_3" reads:
      | tags |  |

  Scenario: A rule tag I removed stays off on the next sync
    Given an API token
    And the saved task rules:
      | pattern       | tags |
      | aaronmallen/* | ruby, hanami |
    And GitHub assigns me the issues:
      | number |
      | 7      |
    When the GitHub issue sync runs
    And the database runs:
      """
      DELETE FROM task_tags WHERE tag_id = (SELECT id FROM tags WHERE name = 'hanami')
      """
    And the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | tags | ruby |

  Scenario: A rule's project tags land on a new issue in the project it files into
    Given an API token
    And the projects:
      | name | key  |
      | Pod  | POD  |
      | Blog | BLOG |
    And the saved task rules:
      | pattern   | tags  | projects |
      | acme/*    | audio | Pod      |
      | acme/site |       | Blog     |
    And GitHub assigns me the issues:
      | number | repo      |
      | 1      | acme/tool |
      | 2      | acme/site |
    When the GitHub issue sync runs
    Then the task from the issue "I_1" reads:
      | project | Pod       |
      | tags    | audio@POD |
    And the task events from the issue "I_1" read "tagged audio"
    And the task from the issue "I_2" reads:
      | project | Blog       |
      | tags    | audio@BLOG |

  Scenario: The first matching rule files the issue into its project, private or archived, the exact rule first
    Given an API token
    And the projects:
      | name    | key  | visibility | archived  | repo        |
      | Blog    | BLOG | private    |           |             |
      | Site    | SITE | public     | today - 1 |             |
      | Pod     | POD  | public     |           |             |
      | Octopod | OCT  | public     |           | octocat/pod |
    And the saved task rules:
      | pattern                    | tags | projects |
      | aaronmallen/aaronmallen.me |      | Site     |
      | aaronmallen/*              | ruby | Blog     |
      | aaronmallen/pod            |      | Pod      |
    And GitHub assigns me the issues:
      | number | repo                       |
      | 1      | aaronmallen/aaronmallen.me |
      | 2      | AaronMallen/Pod            |
      | 3      | octocat/pod                |
      | 4      | octocat/aaronmallen.me     |
    When the GitHub issue sync runs
    Then the task from the issue "I_1" reads:
      | project | Site |
    And the task from the issue "I_2" reads:
      | project | Pod |
    And the task from the issue "I_3" reads:
      | project |  |
    And the task from the issue "I_4" reads:
      | project |  |
    And the database soon holds "I_1 1, I_2 1, I_3 1, I_4 2" for:
      """
      SELECT string_agg(remote_id || ' ' || number, ', ' ORDER BY remote_id) FROM tasks JOIN task_sources ON task_id = tasks.id
      """

  Scenario: A rule's project I removed stays off on the next sync
    Given an API token
    And the projects:
      | name | key  |
      | Site | SITE |
    And the saved task rules:
      | pattern       | projects |
      | aaronmallen/* | Site     |
    And GitHub assigns me the issues:
      | number |
      | 7      |
    When the GitHub issue sync runs
    And the database runs:
      """
      UPDATE tasks SET project_id = NULL, number = 99
      """
    And the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | project |  |

  Scenario: An issue edited on GitHub moves its task in step, and an unchanged one leaves it alone
    Given the tasks tracking issues:
      | title     | note     | number |
      | Old       | Old body | 7      |
      | Unchanged | Same     | 8      |
      | Renamed   | Here     | 9      |
    And GitHub assigns me the issues:
      | number | title     | body     | repo                       |
      | 7      | New       | New body | aaronmallen/aaronmallen.me |
      | 8      | Unchanged | Same     | aaronmallen/aaronmallen.me |
      | 9      | Renamed   | Here     | aaronmallen/renamed        |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | title | New      |
      | note  | New body |
    And the task from the issue "I_8" reads:
      | touched | false |
    And the task from the issue "I_9" reads:
      | url | https://github.com/aaronmallen/renamed/issues/9 |

  Scenario: An issue with a NUL byte imports without it and keeps step
    Given the tasks tracking issues:
      | title          | note              | number |
      | Sync my issues | Keep them in step | 8      |
    And GitHub assigns me the issues:
      | number | title              | body                   |
      | 7      | Sync\u0000 my issues | Keep\u0000 them in step |
      | 8      | Sync\u0000 my issues | Keep\u0000 them in step |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | title | Sync my issues    |
      | note  | Keep them in step |
    And the task from the issue "I_8" reads:
      | touched | false |
    When GitHub assigns me the issues:
      | number | title                 | body                       |
      | 7      | Sync\u0000 every issue | Keep\u0000 them all in step |
    And the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | title | Sync every issue      |
      | note  | Keep them all in step |

  Scenario: An issue whose title is blank once cleaned takes its reference until it has a title
    Given GitHub assigns me the issues:
      | number | title          |
      | 7      | \u0000 \u0000  |
      | 8      | \u0000         |
    When the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | title | aaronmallen/aaronmallen.me#7 |
    When GitHub assigns me the issues:
      | number | title          | body     |
      | 7      | \u0000 \u0000  | New body |
      | 8      | Sync my work   |          |
    And the GitHub issue sync runs
    Then the task from the issue "I_7" reads:
      | title | aaronmallen/aaronmallen.me#7 |
      | note  | New body                     |
    And the task from the issue "I_8" reads:
      | title | Sync my work |
