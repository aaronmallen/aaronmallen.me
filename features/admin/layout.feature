Feature: Admin layout
  Every admin page shares a top bar with pills, a switcher, an avatar menu, the command palette, a footer and the
  dialog shells, in place of the public site header.

  Scenario: Today opens under the top bar with its pills, menus and palette
    Given I am signed in to the admin
    When I visit "/admin"
    Then the admin markup holds "header.top-bar + main#main"
    And the admin markup lacks ".site-header, .ctx-bar"
    And the admin markup holds "header.top-bar > a.top-bar-skip[href='#main'] + a.wordmark[href='/']"
    And the admin texts of "nav.pill-nav a.pill-nav-link" are:
      | Today    |
      | Inbox    |
      | Tasks    |
      | Journal  |
      | Publish  |
      | Agents   |
      | Insights |
    And the admin links of "a.pill-nav-link" are:
      | /admin                 |
      | /admin/inbox           |
      | /admin/tasks           |
      | /admin/journal         |
      | /admin/posts           |
      | /admin/agents/memories |
      | /admin/analytics       |
    And the admin markup holds 1 of "a.pill-nav-link[aria-current='page']:text-is('Today')"
    And the admin markup holds 1 of "a.pill-nav-link[aria-current='page']"
    And the admin markup holds "button.top-bar-search[data-palette-open][data-key='/']"
    And the admin markup holds "button.avatar[popovertarget='avatar-menu'] + #avatar-menu[popover]"
    And the admin markup holds ".switcher[popovertarget='nav-switcher'] + #nav-switcher[popover]"
    And the admin markup lacks ".screen-tabs"
    And the page title is "Today | Admin | Aaron Allen"
    And the admin markup holds "main#main .page-head h1:has-text('Nothing planned yet.')"
    And the page kicker shows today's date
    And the admin markup lacks "head link[rel='alternate']"
    And the admin markup holds "link[rel='stylesheet'][href*='app']"
    And the admin markup holds "script[src*='app']"

  Scenario: The switcher lists every screen but settings, grouped on two sides
    Given I am signed in to the admin
    When I visit "/admin"
    Then the admin links of "#nav-switcher a.switcher-row" are, in any order:
      | /admin                 |
      | /admin/inbox           |
      | /admin/mail            |
      | /admin/webmentions     |
      | /admin/contacts        |
      | /admin/tasks           |
      | /admin/calendar        |
      | /admin/projects        |
      | /admin/journal         |
      | /admin/notes           |
      | /admin/decisions       |
      | /admin/review          |
      | /admin/posts           |
      | /admin/social          |
      | /admin/files           |
      | /admin/links           |
      | /admin/agents/memories |
      | /admin/agents/artifacts |
      | /admin/agents/sessions |
      | /admin/analytics       |
      | /admin/activity        |
      | /admin/health          |
      | /admin/time            |
    And the switcher sides open with:
      | today, Tasks, Publish, Insights |
      | Inbox, Journal, Agents          |
    And the admin markup holds 1 of "#nav-switcher a.switcher-row[aria-current='page']"
    And the admin markup holds "#nav-switcher a.switcher-row[aria-current='page']:text-is('today')"
    And the admin markup holds "button.switcher[aria-label='Navigate. Current: Today']"

  Scenario: The avatar menu links the site and settings and offers the keys, themes and sign out
    Given I am signed in to the admin
    When I visit "/admin"
    Then the admin links of "#avatar-menu a.avatar-menu-item" are:
      | /writing        |
      | /about          |
      | /projects       |
      | /contact        |
      | /admin/settings |
    And the admin markup holds "#avatar-menu a.avatar-menu-item[href='/admin/settings'] .fa-gear"
    And the admin markup holds "#avatar-menu button.avatar-menu-item[data-key='?'][data-key-help-open]"
    And the admin markup holds 2 of "#avatar-menu button.avatar-menu-item[data-theme-choice]"
    And the admin markup holds "#avatar-menu form[action='/admin/sign-out'] button.avatar-menu-item[type='submit']:has-text('Sign out')"
    And the admin markup lacks "main form[action='/admin/sign-out']"

  Scenario: The palette offers each screen and searches every record
    Given I am signed in to the admin
    When I visit "/admin"
    Then the admin markup holds "dialog#command-palette"
    And the admin markup lacks "button.slash"
    And the admin markup holds "[data-palette-search='/admin/search/palette']"
    And the palette offers the sections:
      | /admin                      |
      | /admin/inbox                |
      | /admin/mail                 |
      | /admin/webmentions          |
      | /admin/contacts             |
      | /admin/tasks                |
      | /admin/calendar             |
      | /admin/projects             |
      | /admin/journal              |
      | /admin/notes                |
      | /admin/decisions            |
      | /admin/review               |
      | /admin/posts                |
      | /admin/social               |
      | /admin/files                |
      | /admin/links                |
      | /admin/agents/memories      |
      | /admin/agents/artifacts     |
      | /admin/agents/sessions      |
      | /admin/analytics            |
      | /admin/activity             |
      | /admin/health               |
      | /admin/time                 |
      | /admin/settings/webmentions |
      | /admin/settings/tagging     |
      | /admin/settings/services    |
      | /admin/settings/security    |
      | /admin/settings/jobs        |

  Scenario: The footer shows the version as text between the confirm template and the palette
    Given I am signed in to the admin
    When I visit "/admin"
    Then the admin markup holds "main#main ~ footer.adm-footer:has-text('Version ')"
    And the admin markup lacks "footer.adm-footer a"
    And the admin markup holds "main#main ~ template[data-confirm-template] + footer.adm-footer"
    And the admin markup holds "footer.adm-footer ~ dialog#command-palette"

  Scenario: Every dialog shell is a modal the dialog script hooks
    Given I am signed in to the admin
    When I visit "/admin"
    Then the admin markup holds "dialog#key-help.dialog.modal[role='dialog'][aria-modal='true'] > .dialog-box > .dialog-head + .dialog-body > dl.keys"
    And the admin markup holds "dialog#key-help.dialog[aria-labelledby='key-help-title'] > .dialog-box > .dialog-head > h2#key-help-title + button[data-dialog-close][aria-label='Close']"
    And the admin markup lacks "dialog.dialog:not([data-dialog])"
    And the admin markup holds "dialog#key-help[data-dialog]:not([data-dialog='static'])"
    And the admin markup holds "dialog#task-create[data-dialog='static']"
    And the admin markup holds "dialog#journal-write[data-dialog='static']"
    And the admin markup holds "[data-dialog-open='key-help'][aria-haspopup='dialog']"
    And the admin markup lacks "[data-dialog-open]:not([aria-haspopup='dialog'])"
    And the admin markup holds "dialog#task-panel.dialog.wide.task-panel[data-dialog][data-task-panel][aria-modal='true'][aria-label] > .dialog-box > .dialog-body[tabindex='-1'][data-task-panel-body]:empty"
    And the admin markup lacks "dialog#task-panel[aria-labelledby]"
    And the admin markup lacks "[class*='task-dialog']"

  Scenario: A screen under a pill marks its pill and lists the pill's screens as tabs
    Given I am signed in to the admin
    When I visit "/admin/inbox"
    Then the admin markup holds 1 of "a.pill-nav-link[aria-current='page']"
    And the admin markup holds "a.pill-nav-link[aria-current='page']:text-is('Inbox')"
    And the admin links of ".page-head + .screen-tabs a.screen-tab" are:
      | /admin/inbox       |
      | /admin/mail        |
      | /admin/webmentions |
      | /admin/contacts    |
    And the admin texts of ".page-head + .screen-tabs a.screen-tab" are:
      | waiting    |
      | mail       |
      | mentions   |
      | contacts 0 |
    And the admin texts of ".screen-tab-note" are:
      | 0 |
    And the admin markup holds 1 of "a.screen-tab[aria-current='page']"
    And the admin markup holds "a.screen-tab[aria-current='page']:text-is('waiting')"

  Scenario: A settings screen marks no pill and lists the settings tabs
    Given I am signed in to the admin
    When I visit "/admin/settings/services"
    Then the admin markup lacks "a.pill-nav-link[aria-current]"
    And the admin markup holds "a.screen-tab:has-text('tagging') + a.screen-tab:has-text('webmentions') + a.screen-tab:has-text('connected services') + a.screen-tab:has-text('jobs') + a.screen-tab:has-text('security')"
    And the admin markup holds 5 of "a.screen-tab"
    And the admin markup holds "a.screen-tab[aria-current='page']:has-text('connected services')"

  Scenario Outline: A settings tab heads as Settings and names itself in the title
    Given I am signed in to the admin
    When I visit "<route>"
    Then the admin markup holds ".page-head h1:text-is('Settings')"
    And the page title is "<title> | Admin | Aaron Allen"
    And the admin markup holds 1 of ".screen-tabs"

    Examples:
      | route                       | title              |
      | /admin/settings/tagging     | Tagging            |
      | /admin/settings/webmentions | Webmentions        |
      | /admin/settings/services    | Connected services |
      | /admin/settings/security    | Security           |
      | /admin/settings/jobs        | Jobs               |

  Scenario Outline: The switcher names Settings and the settings tab
    Given I am signed in to the admin
    When I visit "<route>"
    Then the admin markup holds "button.switcher .switcher-group:text-is('Settings')"
    And the admin markup holds "button.switcher .switcher-screen:text-is('<screen>')"
    And the admin markup holds "[data-palette-href='<route>']"

    Examples:
      | route                       | screen             |
      | /admin/settings/tagging     | tagging            |
      | /admin/settings/webmentions | webmentions        |
      | /admin/settings/services    | connected services |
      | /admin/settings/jobs        | jobs               |

  Scenario: An address nothing lives at answers 404 in the admin layout
    Given I am signed in to the admin
    Then visiting "/admin/nowhere" answers 404
    And the admin markup holds "header.top-bar + main#main .page-head h1:has-text('Page not found')"
    And the admin markup holds "footer.adm-footer:has-text('Version ')"

  Scenario: A failed sign-in shows the site header, not the admin's
    When I fail a GitHub sign-in
    Then the admin markup holds "header.site-header + main#main .page-head h1:has-text('Sign-in failed')"
    And the admin markup lacks "header.top-bar"
    And the admin links of "nav.main-nav a.main-nav-link" are:
      | /writing  |
      | /about    |
      | /projects |
      | /contact  |
    And the page title is "Sign-in failed | Admin | Aaron Allen"
    And the admin markup lacks ".pill-nav, #avatar-menu, dialog#command-palette"
    And the admin markup holds "footer.adm-footer:has-text('Version ')"
    And the admin markup lacks "template[data-confirm-template]"
    And the admin markup holds ".main-nav-settings button[data-theme-toggle]"
    And the admin markup lacks "#settings-menu"

  Scenario Outline: The layout's pages pass axe
    Given I am signed in to the admin
    When I visit "<route>"
    Then the page has no axe breaches in light or dark

    Examples:
      | route                       |
      | /admin                      |
      | /admin/inbox                |
      | /admin/settings/services    |
      | /admin/settings/tagging     |
      | /admin/settings/webmentions |
      | /admin/settings/security    |
      | /admin/settings/jobs        |
      | /admin/nowhere              |

  Scenario: The failed sign-in page passes axe
    When I fail a GitHub sign-in
    Then the page has no axe breaches in light or dark
