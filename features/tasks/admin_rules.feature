Feature: Task rules in the admin
  The tagging tab lists the task rules under the tags, and adds, edits and deletes them.

  Background:
    Given an API token

  Scenario: The rule list shows each rule's pattern, provider, tags and project, and fills its editor
    Given I am signed in to the admin
    And the projects:
      | name  |
      | Blog  |
      | Atlas |
    And the API calls answer:
      | call             | body                                                           | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["projects"]}             | 201    | |
      | POST /task_rules | {"pattern": "aaronmallen/aaronmallen.me", "tags": ["ruby", "hanami"]} | 201 | |
      | POST /task_rules | {"pattern": "acme/ENG", "provider": "linear", "tags": ["work"]} | 201   | |
      | POST /task_rules | {"pattern": "octocat/*", "projects": [1]}                      | 201    | |
    When I visit "/admin/settings/tagging"
    Then the page parts ".rule-pattern" read "aaronmallen/* | aaronmallen/aaronmallen.me | acme/eng | octocat/*"
    And the page parts ".rule-row .rule-provider" read "GitHub | GitHub | Linear | GitHub"
    And the page parts ".rule-tags a.tag" have "href" set to "/admin/tags/projects | /admin/tags/hanami | /admin/tags/ruby | /admin/tags/work"
    And the page parts ".rule-tags a.tag" read "#projects | #hanami | #ruby | #work"
    And the page part "#task-rules .card-side" holds "4 rules"
    And the page field "form[action='/admin/tasks/rules/2#task-rules'] input[name='rule[pattern]']" holds "aaronmallen/aaronmallen.me"
    And the page field "form[action='/admin/tasks/rules/2#task-rules'] input[name='rule[tags]']" holds "hanami, ruby"
    And the page part "form[action='/admin/tasks/rules/3#task-rules'] select[name='rule[provider]'] option[selected]" has "value" set to "linear"
    And the page parts ".rule-row:has-text('octocat/*') .rule-project" read "Blog"
    And the page parts "form[action='/admin/tasks/rules/4#task-rules'] input[name='rule[projects][]'][checked]" have "value" set to "1"
    And the page parts ".settings-section" have "id" set to "tags | task-rules"
    And the page has 4 of "#task-rules .rule-row"
    And the page part "nav[aria-label='Settings tabs'] a[aria-current='page']" holds "tagging"
    And the page part "nav[aria-label='Settings tabs'] a[aria-current='page'] .settings-tab-count" reads "4"
    And the page part "#task-rules .card-blurb" reads "Each rule gives the issues it matches private tags as they sync, and a project when they have none."
    And the page has 1 of ".hint:text-is('Editing or deleting a rule changes only new imports. Tasks keep the tags and projects they have.')"
    And the page part "form[action='/admin/tasks/rules/1/delete']" has "data-confirm" set to "Delete the GitHub rule for aaronmallen/*? Tasks keep the tags and projects it gave them."
    And the page has no axe breaches in light or dark
    When I visit "/admin/settings/security"
    Then the page part "nav[aria-label='Settings tabs'] a:has-text('tagging') .settings-tab-count" reads "4"

  Scenario: The rules have an old address, a palette entry and a link from the external tab
    Given I am signed in to the admin
    When I fetch the admin page "/admin/tasks/rules"
    Then the admin answer goes to "/admin/settings/tagging#task-rules"
    When I visit "/admin"
    Then the page has "[data-palette-href='/admin/settings/tagging']"
    When I visit "/admin/tasks?filter=external"
    Then the page part "a:text-is('Task rules')" has "href" set to "/admin/settings/tagging#task-rules"
    When I visit "/admin/settings/tagging"
    Then the page has "#task-rules .empty"

  Scenario: The add form posts to its section and offers each provider and every project
    Given I am signed in to the admin
    And the projects:
      | name  | visibility | archived  | started    |
      | Blog  | private    |           |            |
      | Atlas | public     | today - 1 | today - 30 |
    And the admin scripts do not load
    When I visit "/admin/settings/tagging"
    Then the page has "form.rule-capture[action='/admin/tasks/rules#task-rules']"
    And the page parts ".rule-capture select[name='rule[provider]'] option" read "GitHub | Linear"
    And the page parts ".rule-capture select[name='rule[provider]'] option" have "value" set to "github | linear"
    And the page part ".rule-capture select[name='rule[provider]'] option[selected]" has "value" set to "github"
    And the page parts ".rule-capture .rule-projects .choice" read "Atlas archived | Blog"
    And the page part ".rule-capture .hint" holds "Adding a rule also tags every imported task it matches, and gives its project to each with none."

  Scenario: Adding a rule stores it, says so and applies it to the tasks already imported
    Given I am signed in to the admin
    And the projects:
      | name | key  |
      | Blog | BLOG |
    And the tasks:
      | title | list     |
      | blog  | external |
    And the task sources:
      | task | url                                       |
      | blog | https://github.com/aaronmallen/blog/issues/1 |
    When I send the admin form "/admin/tasks/rules" with:
      | rule[pattern]    | AaronMallen/*     |
      | rule[provider]   | github            |
      | rule[tags]       | projects, ruby    |
      | rule[projects][] | 1                 |
    Then the admin answer goes to "/admin/settings/tagging#task-rules"
    And the database reads "github, aaronmallen/*" for:
      """
      SELECT provider, pattern FROM task_rules
      """
    And the tags on each task read "blog: projects ruby"
    And the database reads "BLOG" for:
      """
      SELECT key FROM tasks JOIN projects ON projects.id = project_id
      """
    When I follow the admin answer
    Then the toast says "Rule added"
    When I send the admin form "/admin/tasks/rules" with:
      | rule[pattern]  | acme/ENG |
      | rule[provider] | linear   |
      | rule[tags]     | work     |
    Then the database reads "linear, acme/eng" for:
      """
      SELECT provider, pattern FROM task_rules WHERE id = 2
      """
    When I send the admin form "/admin/tasks/rules" with:
      | rule[pattern]    | octocat/* |
      | rule[provider]   | github    |
      | rule[tags]       |           |
      | rule[projects][] | 1         |
    Then the database reads "1" for:
      """
      SELECT count(*) FROM task_rules WHERE pattern = 'octocat/*'
      """

  Scenario Outline: Adding a rule refuses <pattern>, says why and saves nothing
    Given I am signed in to the admin
    When I send the admin form "/admin/tasks/rules" with:
      | rule[pattern]  | <pattern> |
      | rule[provider] | github    |
      | rule[tags]     | brand-new |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#rule-pattern-error" holds "Name one repo or team as owner/name, or all of an owner's as owner/*."
    And the database holds 0 task_rules rows
    And the database holds 0 tags rows

    Examples:
      | pattern             |
      | aaronmallen         |
      | */foo               |
      | aaronmallen/foo/bar |

  Scenario: Adding a rule says why it refused and keeps what was typed
    Given I am signed in to the admin
    And the projects:
      | name |
      | One  |
      | Two  |
    And the API calls answer:
      | call             | body                                          | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["ruby"]} | 201   | |
    Then the admin rule form refuses:
      | pattern       | provider | tags  | projects | field    | error                                    |
      | "  "          | github   | ruby  |          | pattern  | Name a repo or team first.               |
      | AaronMallen/* | github   | ruby  |          | pattern  | Another rule already holds that pattern. |
      | octocat/*     | github   | " , " |          | tags     | Name a tag or a project first.           |
      | octocat/*     | github   |       | 999999   | projects | One of those projects is gone.           |
      | octocat/*     | github   |       | 1, 2     | projects | Pick one project at most.                |
      | octocat/*     | github   | c++   |          | tags     |                                          |
    And the database holds 1 task_rules row
    When I send the admin form "/admin/tasks/rules" with:
      | rule[pattern]    | aaronmallen |
      | rule[provider]   | linear      |
      | rule[tags]       | ruby        |
      | rule[projects][] | 1           |
    And I look at the admin answer
    Then the page has "#rule-provider option[value='linear'][selected]"
    And the page has "#rule-pattern[value='aaronmallen']"
    And the page has "#rule-tags[value='ruby']"
    And the page has ".rule-capture input[name='rule[projects][]'][value='1'][checked]"

  Scenario: Editing a rule rewrites it and says so
    Given I am signed in to the admin
    And the projects:
      | name |
      | Blog |
    And the API calls answer:
      | call             | body                                                         | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["projects"]}           | 201    | |
      | POST /task_rules | {"pattern": "octocat/*", "tags": ["ruby"], "projects": [1]}  | 201    | |
    When I send the admin form "/admin/tasks/rules/1" with:
      | rule[pattern] | aaronmallen/aaronmallen.me |
      | rule[tags]    | ruby                       |
    Then the admin answer goes to "/admin/settings/tagging#task-rules"
    When I follow the admin answer
    Then the toast says "Rule saved"
    When I send the admin form "/admin/tasks/rules/1" with:
      | rule[pattern]    | aaronmallen/aaronmallen.me |
      | rule[tags]       |                            |
      | rule[projects][] | 1                          |
    And I send the admin form "/admin/tasks/rules/2" with:
      | rule[pattern] | octocat/* |
      | rule[tags]    | ruby      |
    And I send the admin form "/admin/tasks/rules/2" with:
      | rule[pattern]  | acme/*  |
      | rule[provider] | linear  |
      | rule[tags]     | ruby    |
    Then the API calls answer:
      | call            | body | status | holds |
      | GET /task_rules |      | 200    | {"task_rules": [{"pattern": "aaronmallen/aaronmallen.me", "provider": "github", "tags": [], "projects": [{"id": 1}]}, {"pattern": "acme/*", "provider": "linear", "tags": ["ruby"], "projects": []}]} |
    When I send the admin form "/admin/tasks/rules/999999" with:
      | rule[pattern] | aaronmallen/* |
      | rule[tags]    | ruby          |
    Then the server answers 404

  Scenario: Editing a rule refuses a bad pattern against its row and keeps the rule
    Given I am signed in to the admin
    And the API calls answer:
      | call             | body                                               | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["projects"]} | 201    | |
    When I send the admin form "/admin/tasks/rules/1" with:
      | rule[pattern] | aaronmallen |
      | rule[tags]    | ruby        |
    Then the server answers 422
    When I look at the admin answer
    Then the page part "#rule-1-pattern-error" holds "Name one repo or team as owner/name, or all of an owner's as owner/*."
    And the page has "#rule-1-pattern[value='aaronmallen']"
    And the page has "#rule-1-edit[checked]"
    And the API calls answer:
      | call            | body | status | holds |
      | GET /task_rules |      | 200    | {"task_rules": [{"pattern": "aaronmallen/*", "tags": ["projects"]}]} |

  Scenario: Editing and deleting a rule leave what the tasks hold
    Given I am signed in to the admin
    And the projects:
      | name | key  |
      | Blog | BLOG |
    And the tasks:
      | title | list     |
      | blog  | external |
    And the task sources:
      | task | url                                |
      | blog | https://github.com/x/blog/issues/1 |
    When I send the admin form "/admin/tasks/rules" with:
      | rule[pattern]    | x/*      |
      | rule[provider]   | github   |
      | rule[tags]       | projects |
      | rule[projects][] | 1        |
    And I send the admin form "/admin/tasks/rules/1" with:
      | rule[pattern] | x/*  |
      | rule[tags]    | ruby |
    And I send the admin form "/admin/tasks/rules/1/delete" with:
      | confirm | yes |
    Then the admin answer goes to "/admin/settings/tagging#task-rules"
    And the database holds 0 task_rules rows
    And the tags on each task read "blog: projects"
    And the database reads "BLOG" for:
      """
      SELECT key FROM tasks JOIN projects ON projects.id = project_id
      """
    When I follow the admin answer
    Then the toast says "Rule deleted"
    When I send the admin form "/admin/tasks/rules/0/delete" with:
      | confirm | yes |
    Then the server answers 404

  Scenario: A forged CSRF token adds and deletes nothing
    Given I am signed in to the admin
    And the API calls answer:
      | call             | body                                           | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["ruby"]} | 201    | |
    When I send the admin form "/admin/tasks/rules" with a forged token and:
      | rule[pattern] | octocat/* |
      | rule[tags]    | ruby      |
    Then the server answers 403
    When I send the admin form "/admin/tasks/rules/1/delete" with a forged token and:
      | confirm | yes |
    Then the database holds 1 task_rules row

  Scenario: Signed out, the rule list sends me to sign in
    Given the API calls answer:
      | call             | body                                               | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["projects"]} | 201    | |
    When I fetch the admin page "/admin/settings/tagging"
    Then the admin answer goes to a page starting "/admin/sign-in"
    And the answer does not show "aaronmallen/*"

  Scenario: The browser adds, edits and deletes a rule
    Given I am signed in to the admin
    And the API calls answer:
      | call             | body                                               | status | holds |
      | POST /task_rules | {"pattern": "aaronmallen/*", "tags": ["projects"]} | 201    | |
    When I visit "/admin/settings/tagging"
    Then the page has no ".rule-editor:visible"
    When I set the page field "#rule-pattern" to "aaronmallen/aaronmallen.me"
    And I set the page field "#rule-tags-search" to "ruby"
    And I click "Add rule"
    Then the page part ".rule-pattern:has-text('aaronmallen/aaronmallen.me')" reads "aaronmallen/aaronmallen.me"
    When I click the page part ".rule-row:has-text('aaronmallen/*') .rule-pattern"
    And I set the page field "#rule-1-tags-search" to "ruby,"
    And I click "Save" in ".rule-editor:visible"
    Then the page has ".rule-row:has-text('aaronmallen/*') .rule-tags .tag:has-text('#ruby')"
    When I click the page part ".rule-row:has-text('aaronmallen/*') .rule-pattern"
    And I click "Delete" in ".rule-editor:visible"
    Then the question reads "Delete the GitHub rule for aaronmallen/*? Tasks keep the tags and projects it gave them."
    When I say no to the question
    Then the database holds 2 task_rules rows
    When I click "Delete" in ".rule-editor:visible"
    And I say yes to the question
    Then the page has no ".rule-row:has-text('aaronmallen/*')"
    And the database holds 1 task_rules row

  Scenario: The browser's project field searches, picks and drops projects
    Given I am signed in to the admin
    And the projects:
      | name  | visibility | archived  | started    |
      | Blog  | public     |           |            |
      | Atlas | public     | today - 1 | today - 30 |
      | Bloom | public     |           |            |
    When I visit "/admin/settings/tagging"
    Then the page has ".rule-capture [data-project-pick-input][role='combobox']"
    And the page hides ".rule-capture .rule-projects"
    When I set the page field ".rule-capture [data-project-pick-input]" to "blo"
    Then the page parts ".rule-capture .project-pick-result" read "Blog | Bloom"
    When I set the page field ".rule-capture [data-project-pick-input]" to "atl"
    Then the page parts ".rule-capture .project-pick-result" read "Atlas archived"
    When I click the page part ".rule-capture .project-pick-result:has-text('Atlas')"
    Then the page parts ".rule-capture .project-pick-chip" read "Atlas archived"
    When I click the page part ".rule-capture button[aria-label='Remove Atlas']"
    Then the page has no ".rule-capture .project-pick-chip"
    When I set the page field ".rule-capture [data-project-pick-input]" to "bloo"
    And I press "ArrowDown"
    And I press "Enter"
    Then the page parts ".rule-capture .project-pick-chip" read "Bloom"
    When I click "Add rule"
    Then the page parts ".rule-capture .project-pick-chip" read "Bloom"
    When I set the page field "#rule-pattern" to "octocat/*"
    And I click "Add rule"
    Then the page parts ".rule-row:has-text('octocat/*') .rule-project" read "Bloom"
    When I click the page part ".rule-row:has-text('octocat/*') .rule-pattern"
    Then the page parts ".rule-editor:visible .project-pick-chip" read "Bloom"
