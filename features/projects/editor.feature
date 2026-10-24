Feature: The project editor
  The editor makes and edits a project: its name, key, source, copy for /projects, placement and board. A
  project with a repo takes the issues already imported from it and a task rule that hands it new ones.

  Background:
    Given I am signed in to the admin

  Scenario: The new editor offers an empty form with the actions it allows
    When I visit "/admin/projects/new"
    Then the page part "title" reads "New project | Admin | Aaron Allen"
    And the page has "header.page-head input.editor-title.mono[name='project[name]'][value='']"
    And the page has "header.page-head .editor-head .page-head-sub [data-editor-repo]"
    And the page part "header.page-head .page-head-actions button" holds "Create project"
    And the page has "button:has-text('Create project')[disabled]"
    And the page has no "button:has-text('Archive')"
    And the page has no "button:has-text('Restore')"
    And the page has ".card:has(.card-title:text-is('Source')) >> role=textbox[name='owner/repo']"
    And the page has ".card:has(.card-title:text-is('Source')) >> role=textbox[name='Link']"
    And the page has "input[type='url'][name='project[og_image_url]'][value='']"
    And the page has "a.bt.gh.sm.editor-back[href='/admin/projects'] > i.fa-arrow-left[aria-hidden='true']:first-child"
    And the page part "a.editor-back" holds "All projects"
    And the page has "form[action='/admin/projects'][method='post']"
    And the page parts "select[name='project[visibility]'] option" read "Pick one | Public | Private"
    And the page part "select[name='project[visibility]'] option:checked" reads "Pick one"
    And the page has "select[name='project[visibility]'][required]"
    And the page box ".card:has(.card-title:text-is('Kanban board')) input.toggle[role='switch'][name='project[board_published]']" is not ticked
    And the page has ".card:has(.card-title:text-is('Kanban board')) label:has-text('Publish Kanban')"
    And the page has no "[name='project[featured]']"
    And the page part ".pc .pn" reads "project-name"
    And the page part ".pc p" reads "One sentence about the project."
    And the page has no axe breaches in light or dark

  Scenario: The editor for a project fills what it holds
    Given the projects:
      | name | tagline         | repo            | url                             | release | stars | started    | tags     |
      | sai  | Terminal colors | aaronmallen/sai | https://github.com/aaronmallen/sai | v1.0.0 | 21 | 2024-06-01 | ruby cli |
    And the tags table holds the rows:
      | name   | color   | scope   |
      | secret | mk-blue | private |
    When I visit "/admin/projects/{project:sai}/edit"
    Then the page part "title" reads "sai | Admin | Aaron Allen"
    And the page has "input[name='project[name]'][value='sai']"
    And the page has "button:has-text('Save project'):not([disabled])"
    And the page part ".page-head-sub" holds "aaronmallen/sai · v1.0.0"
    And the page has "input[name='project[repo]'][value='aaronmallen/sai']"
    And the page has "input[name='project[url]'][value='https://github.com/aaronmallen/sai']"
    And the page field "textarea[name='project[tagline]']" holds "Terminal colors"
    And the page has no "[name='project[readme]']"
    And the page has "input[name='project[started_on]'][value='2024-06']"
    And the page has "input[name='project[tags]'][value='cli, ruby']"
    And the tags suggested for "project[tags]" are "cli, ruby"
    And the page part "select[name='project[visibility]'] option:checked" reads "Public"
    And the page has "button:has-text('Archive')"
    And the page has no "button:has-text('Restore')"
    And the page has "form#project-status-change[action='/admin/projects/1/archive'] input[type='hidden'][name='filter'][value='archived']"
    And the page part ".pgrid .pc .pn" reads "sai"
    And the page part ".pgrid .pc .ps" reads "cli · ruby · ★ 21 · v1.0.0"
    And the page part ".pgrid .pc p" reads "Terminal colors"
    And the page has no axe breaches in light or dark
    When I visit "/admin/projects/999999/edit"
    Then the server answers 404

  Scenario: The editor fills the card image and the published board
    Given the projects:
      | name   | board     |
      | carded | published |
    And the database runs:
      """
      UPDATE projects SET og_image_url = 'https://example.com/card.png';
      """
    When I visit "/admin/projects/{project:carded}/edit"
    Then the page has "input[name='project[og_image_url]'][value='https://example.com/card.png']"
    And the page box "input[name='project[board_published]'][role='switch']" is ticked

  Scenario: The editor shows the stars and release as text and keeps them on save
    Given the projects:
      | name | repo            | stars | release |
      | sai  | aaronmallen/sai | 1204  | v2.1.0  |
    When I visit "/admin/projects/{project:sai}/edit"
    Then the page part ".field-value:has-text('1,204')" reads "1,204"
    And the page part ".field-value:has-text('v2.1.0')" reads "v2.1.0"
    And the page has no "[name='project[stars]']"
    And the page has no "[name='project[release]']"
    When I save a project in the admin with:
      | project          | sai    |
      | project[stars]   | 9999   |
      | project[release] | v9.9.9 |
    Then the project "sai" holds 1204 stars and the release "v2.1.0"

  Scenario: Creating a project saves it, says so, and sends the editor to it
    When I save a project in the admin with:
      | project[og_image_url] | https://example.com/card.png |
      | project[visibility]   | private                      |
    Then the admin answer goes to "/admin/projects/1/edit"
    And the project "sai" reads:
      | tagline      | Terminal colors              |
      | visibility   | private                      |
      | og_image_url | https://example.com/card.png |
      | archived_on  | none                         |
    When I follow the admin answer
    Then the toast says "Project created"

  Scenario: Creating a project takes the imported issues of its repo and a rule that hands it new ones
    Given the tasks:
      | title  | list     |
      | Issue  | external |
    And the task sources:
      | task  | url                                    |
      | Issue | https://github.com/AaronMallen/sai/issues/1 |
    When I save a project in the admin
    Then the database reads "Issue, sai" for:
      """
      SELECT title, projects.name FROM tasks JOIN projects ON projects.id = project_id
      """
    And the task rules read "github aaronmallen/sai sai"

  Scenario: Creating a project gives a rule for its repo that holds no project the project
    Given an API token
    And the tasks:
      | title | list     |
      | Issue | external |
    And the task sources:
      | task  | url                                        |
      | Issue | https://github.com/aaronmallen/sai/issues/1 |
    And I POST "/task_rules" through the API with:
      """
      { "pattern": "aaronmallen/sai", "tags": ["ruby"] }
      """
    When I save a project in the admin
    Then the task rules read "github aaronmallen/sai sai"
    And the database reads "sai" for:
      """
      SELECT projects.name FROM tasks JOIN projects ON projects.id = project_id
      """

  Scenario: Creating a project leaves a rule for its repo that names another project alone
    Given an API token
    And the projects:
      | name  |
      | other |
    And I POST "/task_rules" through the API with:
      """
      { "pattern": "aaronmallen/sai", "tags": ["ruby"], "projects": [1] }
      """
    And the tasks:
      | title | list     |
      | Issue | external |
    And the task sources:
      | task  | url                                        |
      | Issue | https://github.com/aaronmallen/sai/issues/1 |
    When I save a project in the admin
    Then the task rules read "github aaronmallen/sai other"
    And the database reads "" for:
      """
      SELECT project_id FROM tasks WHERE project_id IS NOT NULL
      """

  Scenario: Creating a project while Redis is down still saves it and its rule
    When Redis goes down
    And I save a project in the admin
    Then the server answers 302
    And the project "sai" reads:
      | repo | aaronmallen/sai |
    And the task rules read "github aaronmallen/sai sai"

  Scenario: Creating a project refuses what it cannot store and keeps what was typed
    Given the projects:
      | name       | repo            | url                             | archived  | started    |
      | tracked    | aaronmallen/sai | https://github.com/aaronmallen/sai |       |            |
      | Site Tools |                 |                                 | today - 1 | today - 30 |
    Then the admin project form refuses:
      | field                 | value               | error                                                     |
      | project[visibility]   |                     | Pick who can see it.                                      |
      | project[name]         | "  "                | Add a name.                                               |
      | project[repo]         | Not a repo          | Name the repository as owner/repo, as octocat/hello-world. |
      | project[repo]         | aaronmallen/sai     | Another project already tracks this repository.           |
      | project[name]         | 日本語 !             | Use a letter or a digit, so the board gets a link.        |
      | project[name]         | site-tools          | Another project's name makes the same link.               |
      | project[og_image_url] | card.png            | Enter a link that starts with http:// or https://.        |
    And the database holds 2 projects rows
    When I save a project in the admin with:
      | project[name]    | "  "            |
      | project[repo]    | aaronmallen/new |
      | project[tagline] | Terminal colors |
    And I look at the admin answer
    Then the page field "textarea[name='project[tagline]']" holds "Terminal colors"

  Scenario: The key comes from what is typed, or from the name's first letters
    Given the projects:
      | name  | key | archived  | started    |
      | old   | SAI | today - 1 | today - 30 |
      | other | POD |           |            |
    When I save a project in the admin with:
      | project[name] | sai  |
      | project[key]  | |
      | project[repo] | aaronmallen/one |
    And I save a project in the admin with:
      | project[name] | given |
      | project[key]  | " pod2 " |
      | project[repo] | aaronmallen/two |
    And I save a project in the admin with:
      | project[name] | x |
      | project[key]  | |
      | project[repo] | aaronmallen/three |
    And I save a project in the admin with:
      | project[name] | 1-a.b c |
      | project[key]  | |
      | project[repo] | aaronmallen/four |
    Then the database reads "SAI2 / POD2 / X2 / ABC" for:
      """
      SELECT key FROM projects WHERE id > 2 ORDER BY id
      """
    When I visit "/admin/projects/{project:other}/edit"
    Then the page has "input[name='project[key]'][value='POD']"
    When I save a project in the admin with:
      | project       | other |
      | project[name] | other |
      | project[repo] |       |
      | project[key]  |       |
    Then the project "other" reads:
      | key | OTH |

  Scenario: A blank key on a new project takes the first 3 letters, and its tasks show as KEY-1
    When I save a project in the admin with:
      | project[name] | pod-cast |
      | project[key]  |          |
    And I visit "/admin/projects/1/edit"
    Then the page part "main" holds "Its tasks show as KEY-1. Leave it blank to take the first 3 letters of the name."
    Given the tasks:
      | title  | project  |
      | Record | pod-cast |
    Then the database reads "POD, 1" for:
      """
      SELECT key, number FROM tasks JOIN projects ON projects.id = project_id
      """

  Scenario Outline: The key refuses <key>
    Given the projects:
      | name  | key | archived  | started    |
      | taken | POD | today - 1 | today - 30 |
    When I save a project in the admin with:
      | project[key] | <key> |
    Then the server answers 422
    When I look at the admin answer
    Then the page part ".field-error" holds "<error>"

    Examples:
      | key     | error                                                     |
      | A       | Use 2 to 6 letters and digits that start with a letter, as POD. |
      | 1AB     | Use 2 to 6 letters and digits that start with a letter, as POD. |
      | ABCDEFG | Use 2 to 6 letters and digits that start with a letter, as POD. |
      | A-B     | Use 2 to 6 letters and digits that start with a letter, as POD. |
      | pod     | Another project already has this key.                      |

  Scenario: The editor's hints match what /projects shows
    Given the projects:
      | name  | stars | archived  | started    |
      | first | 30    |           |            |
      | carded | 20   |           |            |
      | second | 10   |           |            |
      | back  | 0     | today - 1 | today - 30 |
      | board | 5     |           |            |
    And the database runs:
      """
      UPDATE projects SET og_image_url = 'https://example.com/first.png' WHERE name = 'carded';
      UPDATE projects SET og_image_url = 'https://example.com/second.png' WHERE name = 'second';
      UPDATE projects SET board_published = true WHERE name = 'board';
      """
    When I visit "/projects"
    Then the page parts ".pc.past .pn" read "back"
    And the page parts "meta[property='og:image']" have "content" set to "https://example.com/first.png"
    And the page part ".pc:has(.pn:text-is('board'))" has "href" set to "/projects/board"
    When I visit "/admin/projects/{project:carded}/edit"
    Then the page part "main" holds "A link to an image you host. The first card with one gives /projects its social card."
    And the page part "main" holds "Stars and release refresh nightly from the GitHub API."
    And the page part "main" holds "The card links here unless its board is published. Leave it blank to use the repository."
    And the page part "main" holds "A public project's card on /projects opens this board."
    And the schedule runs "refresh_projects" "daily at 02:00"
    When I visit "/admin/projects/{project:back}/edit"
    Then the page part "main" holds "Restore moves it out of Past Projects on /projects."
    When I send the admin form "/admin/projects/{project:back}/restore"
    And I visit "/projects"
    Then the page has no ".pc.past"
    And the page has ".pc:not(.past) .pn:text-is('back')"

  Scenario: A blank link points the card at the repository until the board is published
    When I save a project in the admin with:
      | project[url] | |
    And I visit "/projects"
    Then the page part ".pc:has(.pn:text-is('sai'))" has "href" set to "https://github.com/aaronmallen/sai"
    Given the database runs:
      """
      UPDATE projects SET board_published = true;
      """
    When I visit "/projects"
    Then the page part ".pc:has(.pn:text-is('sai'))" has "href" set to "/projects/sai"

  Scenario: The repo and the link fill each other and keep what each names
    Then the admin project form stores:
      | repo                | url                                         | stored repo         | stored url                               |
      | aaronmallen/sai     |                                             | aaronmallen/sai     | https://github.com/aaronmallen/sai       |
      |                     | https://github.com/aaronmallen/sai          | aaronmallen/sai     | https://github.com/aaronmallen/sai       |
      |                     | https://github.com/AaronMallen/Sai          | aaronmallen/sai     | https://github.com/AaronMallen/Sai       |
      | AaronMallen/Sai     |                                             | aaronmallen/sai     | https://github.com/aaronmallen/sai       |
      |                     | https://github.com/aaronmallen/sai.git      | aaronmallen/sai     | https://github.com/aaronmallen/sai.git   |
      | aaronmallen/sai     | https://github.com/AaronMallen/sai          | aaronmallen/sai     | https://github.com/AaronMallen/sai       |
      | aaronmallen/gest    | https://gest.aaronmallen.dev                | aaronmallen/gest    | https://gest.aaronmallen.dev             |
      | aaronmallen/gest    | https://ada:pw@Gest.Example/docs#intro      | aaronmallen/gest    | https://ada:pw@gest.example/docs         |
      |                     | HTTPS://GitHub.com/AaronMallen/Sai          | aaronmallen/sai     | https://github.com/AaronMallen/Sai       |
      |                     | https://github.com/aaronmallen/sai/         | aaronmallen/sai     | https://github.com/aaronmallen/sai       |
      |                     | https://github.com/_foo/bar                 | none                | https://github.com/_foo/bar              |
      |                     | https://github.com/aaronmallen/sai/tree/main | none               | https://github.com/aaronmallen/sai/tree/main |
      |                     | https://github.com/aaronmallen              | none                | https://github.com/aaronmallen           |
      |                     |                                             | none                | none                                     |

  Scenario: The link refuses one that is not a web address
    Then the admin project form refuses:
      | field        | value                    | error                                              |
      | project[url] | gest.aaronmallen.dev     | Enter a link that starts with http:// or https://. |
      | project[url] | javascript:alert(1)      | Enter a link that starts with http:// or https://. |
      | project[url] | mailto:hello@example.com | Enter a link that starts with http:// or https://. |
      | project[url] | /projects/gest           | Enter a link that starts with http:// or https://. |

  Scenario: A renamed repo keeps the link as typed, takes the new repo's issues and keeps each old rule
    Given the projects:
      | name | repo            | url                         |
      | old  | aaronmallen/sai | https://sai.aaronmallen.dev |
    And the tasks:
      | title | list     |
      | Mine  | external |
      | Fresh | external |
    And the task sources:
      | task  | url                                          |
      | Mine  | https://github.com/aaronmallen/sai/issues/1   |
      | Fresh | https://github.com/aaronmallen/fresh/issues/1 |
    When I save a project in the admin with:
      | project       | old                         |
      | project[name] | old                         |
      | project[repo] | aaronmallen/sai             |
      | project[url]  | https://sai.aaronmallen.dev |
    Then the database reads "" for:
      """
      SELECT title FROM tasks WHERE title = 'Mine' AND project_id IS NOT NULL
      """
    When I save a project in the admin with:
      | project       | old                         |
      | project[name] | old                         |
      | project[repo] | aaronmallen/fresh           |
      | project[url]  | https://sai.aaronmallen.dev |
    Then the project "old" reads:
      | repo | aaronmallen/fresh           |
      | url  | https://sai.aaronmallen.dev |
    And the database reads "Fresh" for:
      """
      SELECT title FROM tasks WHERE project_id IS NOT NULL
      """
    When I save a project in the admin with:
      | project       | old               |
      | project[name] | old               |
      | project[repo] | aaronmallen/other |
      | project[url]  |                   |
    And I save a project in the admin with:
      | project       | old |
      | project[name] | old |
      | project[repo] |     |
      | project[url]  |     |
    Then the task rules read "github aaronmallen/fresh old / github aaronmallen/other old"

  Scenario: Updating a project saves its name, tags, visibility, board and start month, and says so
    Given the projects:
      | name | repo            | board     |
      | old  | aaronmallen/sai |           |
      | pub  |                 | published |
    When I save a project in the admin with:
      | project                  | old             |
      | project[name]            | Old             |
      | project[tags]            | Ruby, CLI, ruby |
      | project[visibility]      | private         |
      | project[board_published] | 1               |
      | project[started_on]      | 2024-06         |
    Then the project "Old" reads:
      | tags            | cli ruby   |
      | visibility      | private    |
      | board_published | true       |
      | started_on      | 2024-06-01 |
    When I follow the admin answer
    Then the toast says "Project saved"
    When I save a project in the admin with:
      | project                  | pub |
      | project[name]            | pub |
      | project[repo]            |     |
      | project[board_published] | 0   |
      | project[started_on]      | {month:today} |
    Then the project "pub" reads:
      | board_published | false |
      | started_on      | {month:today}-01 |

  Scenario: Updating a project refuses what it cannot store, with Publish Kanban as it was switched
    Given the projects:
      | name       | repo             | archived   | started    |
      | old        | aaronmallen/sai  |            |            |
      | Site Tools |                  |            |            |
      | gone       | aaronmallen/gone | 2024-06-01 | 2023-01-01 |
    Then the admin project form for "old" refuses:
      | field               | value          | error                                                         |
      | project[name]       | site-tools     | Another project's name makes the same link.                   |
      | project[started_on] | June 2024      | Use the year and the month, as 2024-06.                       |
      | project[started_on] | {month:next}   | Pick this month or one before it.                             |
      | project[tags]       | a/b            | A tag is lowercase words joined by hyphens.                   |
      | project[visibility] | secret         | Pick who can see it from the list.                            |
    And the admin project form for "gone" refuses:
      | field               | value   | error                                                          |
      | project[started_on] | 2025-01 | The start month falls after the day this project was archived. |
    When I save a project in the admin with:
      | project                  | old |
      | project[name]            |     |
      | project[board_published] | 1   |
    And I look at the admin answer
    Then the page box "input[name='project[board_published]'][role='switch']" is ticked
    When I save a project in the admin with:
      | project | 999999 |
    Then the server answers 404

  Scenario: Updating a project keeps a name that only another older project shares a link with
    Given the projects:
      | name | key |
      | old  | OLD |
      | Old  | OL2 |
    When I save a project in the admin with:
      | project          | old  |
      | project[name]    | old  |
      | project[repo]    |      |
      | project[tagline] | Kept |
    Then the server answers 302
    And the database reads "Kept" for:
      """
      SELECT tagline FROM projects WHERE id = 1
      """

  Scenario: An archived project offers Restore and keeps its archive date on save
    Given the projects:
      | name | repo             | archived  | started    |
      | gone | aaronmallen/gone | today - 3 | today - 30 |
    When I visit "/admin/projects/{project:gone}/edit"
    Then the page has "button:has-text('Restore')"
    And the page has no "button:has-text('Archive')"
    And the page has "form#project-status-change[action='/admin/projects/1/restore'] input[type='hidden'][name='filter'][value='live']"
    And the page part ".pill:has-text('archived')" reads "archived"
    And the page part "select[name='project[visibility]'] option:checked" reads "Public"
    And the page has no axe breaches in light or dark
    When I save a project in the admin with:
      | project       | gone             |
      | project[name] | gone             |
      | project[repo] | aaronmallen/gone |
    Then the project "gone" reads:
      | archived_on | {day:today - 3} |

  Scenario: Archiving from the editor archives today and goes to the archived list
    Given the projects:
      | name |
      | live |
    When I visit "/admin/projects/{project:live}/edit"
    Then the page has "form[action='/admin/projects/1/archive']"
    When I send the admin form "/admin/projects/{project:live}/archive" with:
      | filter | archived |
    Then the admin answer goes to a page starting "/admin/projects?filter=archived"
    And the project "live" reads:
      | archived_on | {day:today} |

  Scenario: The project list offers New project, Edit and the board
    Given the projects:
      | name |
      | live |
    When I visit "/admin/projects"
    Then the page has "a.bt.pri[href='/admin/projects/new']:has-text('New project')"
    And the page has ".project-card-acts a[href='/admin/projects/1/edit'][aria-label='Edit']"
    And the page part "a.project-card-name[href='/admin/projects/1']" reads "live"

  Scenario: The browser enables Create project once a name is typed and shows what is typed in the preview
    When I visit "/admin/projects/new"
    Then the page has "button:has-text('Create project')[disabled]"
    When I set the page field "input[name='project[name]']" to "sai"
    Then the page has "button:has-text('Create project'):not([disabled])"
    And the page part ".pc .pn" reads "sai"
    When I set the page field "input[name='project[name]']" to "   "
    Then the page has "button:has-text('Create project')[disabled]"
    When I set the page field "textarea[name='project[tagline]']" to "Terminal colors"
    Then the page part ".pc p" reads "Terminal colors"
    When I set the page field "input[name='project[repo]']" to "aaronmallen/sai"
    Then the page part ".page-head-sub" holds "aaronmallen/sai"

  Scenario: The browser creates the project and fills its link from the repo
    When I visit "/admin/projects/new"
    And I set the page field "input[name='project[name]']" to "sai"
    And I set the page field "input[name='project[repo]']" to "aaronmallen/sai"
    And I pick "Public" in the page select "select[name='project[visibility]']"
    And I click "Create project"
    Then the toast says "Project created"
    And the page field "input[name='project[url]']" holds "https://github.com/aaronmallen/sai"

  Scenario: The preview card stays out of the tab order
    Given the projects:
      | name | repo            | url                                |
      | sai  | aaronmallen/sai | https://github.com/aaronmallen/sai |
    When I visit "/admin/projects/{project:sai}/edit"
    Then the page has "a.pc[tabindex='-1']"

  Scenario: The project choices list the live projects by name, uncached, and only when signed in
    Given the projects:
      | name    | key  | archived  | started    |
      | Site    | SITE |           |            |
      | Podcast | POD  |           |            |
      | Gone    | GONE | today - 1 | today - 30 |
    When I fetch the admin page "/admin/projects/choices" as JSON
    Then the admin answer is:
      """
      { "projects": [{ "key": "POD", "name": "Podcast" }, { "key": "SITE", "name": "Site" }] }
      """
    And the answer header "Cache-Control" is "private, no-store"
    And the answer header "Content-Type" is "application/json; charset=utf-8"
