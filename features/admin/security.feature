Feature: Admin security tab
  The security tab lists each browser that signed in, each failed sign-in, and where each token and client called from.

  Background:
    Given I am signed in to the admin

  Scenario: The security tab sits last among the Settings tabs
    When I visit "/admin/settings/security"
    Then the page heading is "Settings"
    And the settings tabs link to:
      | tagging     | /admin/settings/tagging     |
      | webmentions | /admin/settings/webmentions |
      | services    | /admin/settings/services    |
      | jobs        | /admin/settings/jobs        |
      | security    | /admin/settings/security    |
    And the settings tab "security" is current
    And the palette offers "/admin/settings/security"
    And the page has no axe breaches in light or dark

  Scenario Outline: An old Settings address sends me on
    When I send GET "<old>"
    Then the answer is 302
    And the answer sends me to "<new>"

    Examples:
      | old                     | new                         |
      | /admin/settings         | /admin/settings/tagging     |
      | /admin/settings/socials | /admin/settings/webmentions |
      | /admin/security         | /admin/settings/security    |

  Scenario: Only this browser shows when nothing else has signed in
    When I visit "/admin/settings/security"
    Then the "Sign-ins" card lists nothing
    And the "Sign-ins" card notes "0 failed in the last 7 days"
    And the page says "Each browser you signed in from, each failed sign-in, and where each token and client has called from."
    And the page has no link "Errors on Honeybadger"

  Scenario: A browser that signed in three times shows as one device with its last sign-in
    Given the table devices holds:
      | browser | os  | last_signed_in_at |
      | Safari  | iOS | 1 minute ago      |
    And the table sign_ins holds:
      | device_id                    | outcome   | provider | address     | user_agent | browser | os    | city   | country | created_at     |
      | (SELECT id FROM devices WHERE browser = 'Safari') | signed_in | github   | 81.2.69.160 | Chrome/141 | Chrome  | macOS | Austin | US      | 1 hour ago     |
      | (SELECT id FROM devices WHERE browser = 'Safari') | signed_in | github   | 81.2.69.160 | Chrome/141 | Chrome  | macOS | Austin | US      | 10 minutes ago |
      | (SELECT id FROM devices WHERE browser = 'Safari') | signed_in | google   | 203.0.113.9 | Chrome/141 | Chrome  | macOS | Paris  | FR      | 1 minute ago   |
    When I visit "/admin/settings/security"
    Then the "Sign-ins" card lists:
      | Safari · iOS |
    And the "Safari · iOS" row in "Sign-ins" says "Google · Paris · FR · 203.0.113.9"
    And the "Safari · iOS" row in "Sign-ins" shows 1 time
    And the "Safari · iOS" row in "Sign-ins" shows the green pill "signed in"

  Scenario: Two browsers show as two devices, last signed in first
    Given the table devices holds:
      | browser | os    | last_signed_in_at |
      | Firefox | Linux | 10 minutes ago    |
      | Safari  | iOS   | 1 minute ago      |
    When I visit "/admin/settings/security"
    Then the "Sign-ins" card lists:
      | Safari · iOS    |
      | Firefox · Linux |

  Scenario: Signing out a device asks first, stamps it and says so
    Given the table devices holds:
      | browser | os  | last_signed_in_at |
      | Safari  | iOS | 1 minute ago      |
    When I visit "/admin/settings/security"
    And I press "Sign out" in the "Safari · iOS" row of "Sign-ins"
    Then I am asked "Sign out Safari · iOS? It will have to sign in again."
    When I confirm
    Then the page toasts "Device signed out · it has to sign in again"
    And the "Safari · iOS" row in "Sign-ins" shows the plain pill "signed out"
    And the "Safari · iOS" row in "Sign-ins" offers nothing
    And the database answers "1" for:
      """
      SELECT count(*) FROM devices WHERE browser = 'Safari' AND signed_out_at > now() - interval '1 minute'
      """

  Scenario: Signing out a device comes back to the tab
    Given the table devices holds:
      | id                                   | browser | os  | last_signed_in_at |
      | 6f1c0c39-3f5b-4a59-9d3a-2a1d4c5e7f80 | Safari  | iOS | 1 minute ago      |
    When I post to "/admin/settings/security/devices/6f1c0c39-3f5b-4a59-9d3a-2a1d4c5e7f80/sign-out"
    Then the answer sends me to "/admin/settings/security"

  Scenario: Signing out a device ID that is no ID is not found
    When I post to "/admin/settings/security/devices/not-an-id/sign-out"
    Then the answer is 404

  Scenario: A device signed in again after a sign-out pills as signed in
    Given the table devices holds:
      | browser | os  | last_signed_in_at | signed_out_at |
      | Safari  | iOS | now               | 1 minute ago  |
    When I visit "/admin/settings/security"
    Then the "Safari · iOS" row in "Sign-ins" shows the green pill "signed in"
    And the "Safari · iOS" row in "Sign-ins" offers "Sign out"

  Scenario: A device's failed sign-in lists beside it
    Given the table devices holds:
      | browser | os  | last_signed_in_at |
      | Safari  | iOS | now               |
    And the table sign_ins holds:
      | device_id                                         | outcome | provider | address     | user_agent | browser | os  |
      | (SELECT id FROM devices WHERE browser = 'Safari') | denied  | github   | 81.2.69.160 | Safari/18  | Safari  | iOS |
    When I visit "/admin/settings/security"
    Then the "Sign-ins" card lists:
      | Safari · iOS |
      | Safari · iOS |
    And the "Safari · iOS" row in "Sign-ins" shows the green pill "signed in"
    And the "Sign-ins" card says "denied"

  Scenario: A device whose sign-ins were pruned has no name or place
    Given the table devices holds:
      | browser | os   | last_signed_in_at |
      | null    | null | 100 days ago      |
    When I visit "/admin/settings/security"
    Then the "Unknown device" row in "Sign-ins" says "Unknown place"

  Scenario: Sign-ins list newest first with their outcome, place, address and time
    Given the table sign_ins holds:
      | outcome       | provider | address     | user_agent | browser | os    | city   | country | created_at   |
      | signed_in     | github   | 81.2.69.160 | Safari/18  | Safari  | macOS | London | GB      | 1 minute ago |
      | wrong_account | github   | 203.0.113.9 | Firefox/1  | Firefox | macOS | Paris  | FR      | now          |
    When I visit "/admin/settings/security"
    Then the "Sign-ins" card lists:
      | Firefox · macOS |
      | Safari · macOS  |
    And the "Firefox · macOS" row in "Sign-ins" says "Paris · FR · 203.0.113.9"
    And the "Firefox · macOS" row in "Sign-ins" shows the pink pill "wrong account"
    And the "Firefox · macOS" row in "Sign-ins" shows 1 time
    And the "Safari · macOS" row in "Sign-ins" shows the green pill "signed in"

  Scenario: Failed sign-ins list only from the last 7 days until dismissed
    Given the table sign_ins holds:
      | outcome       | provider | address     | user_agent | browser | os    | created_at  | dismissed_at |
      | denied        | github   | 81.2.69.160 | Edge/1     | Edge    | macOS | 6 days ago  |              |
      | wrong_account | github   | 81.2.69.160 | Firefox/1  | Firefox | macOS | 8 days ago  |              |
      | denied        | github   | 81.2.69.160 | Opera/1    | Opera   | macOS | now         | now          |
      | signed_in     | github   | 81.2.69.160 | Safari/1   | Safari  | macOS | 30 days ago |              |
    When I visit "/admin/settings/security"
    Then the "Sign-ins" card notes "1 failed in the last 7 days"
    And the "Sign-ins" card lists:
      | Edge · macOS   |
      | Safari · macOS |
    And the "Edge · macOS" row in "Sign-ins" offers "Dismiss"
    And the "Safari · macOS" row in "Sign-ins" offers nothing

  Scenario: Dismissing a failed sign-in keeps the row but takes it off the list and the count
    Given the table sign_ins holds:
      | outcome | provider | address     | user_agent | browser | os    |
      | denied  | github   | 81.2.69.160 | Edge/1     | Edge    | macOS |
    When I visit "/admin/settings/security"
    And I press "Dismiss" in the "Edge · macOS" row of "Sign-ins"
    Then the page toasts "Failed sign-in dismissed"
    And the "Sign-ins" card lists nothing
    And the "Sign-ins" card notes "0 failed in the last 7 days"
    And the database answers "1" for:
      """
      SELECT count(*) FROM sign_ins WHERE dismissed_at > now() - interval '1 minute'
      """
    When I post to "/admin/settings/security/sign-ins/1/dismiss"
    Then the answer is 404

  Scenario: Dismissing a failed sign-in comes back to the tab
    Given the table sign_ins holds:
      | outcome | provider | address     | user_agent |
      | denied  | github   | 81.2.69.160 | Edge/1     |
    When I post to "/admin/settings/security/sign-ins/1/dismiss"
    Then the answer sends me to "/admin/settings/security"

  Scenario: Dismissing a sign-in that went through is not found
    Given the table sign_ins holds:
      | outcome   | provider | address     | user_agent |
      | signed_in | github   | 81.2.69.160 | Edge/1     |
    When I post to "/admin/settings/security/sign-ins/1/dismiss"
    Then the answer is 404
    And the database answers "0" for:
      """
      SELECT count(*) FROM sign_ins WHERE dismissed_at IS NOT NULL
      """

  Scenario: Sign-ins page a hundred at a time, newest first
    Given the database runs:
      """
      INSERT INTO sign_ins (outcome, provider, address, user_agent, browser, os, created_at)
      SELECT 'signed_in', 'github', '81.2.69.160', 'ua', 'Browser ' || n, 'macOS', now() - n * interval '1 minute'
      FROM generate_series(1, 101) AS n
      """
    When I visit "/admin/settings/security"
    Then the "Browser 1 · macOS" row in "Sign-ins" says "signed in"
    And the pager links "Older" to "/admin/settings/security?page=2"
    When I visit "/admin/settings/security?page=2"
    Then the "Sign-ins" card lists:
      | Browser 101 · macOS |
    And the pager links "Newer" to "/admin/settings/security"
    When I send GET "/admin/settings/security?page=3"
    Then the answer is 404

  Scenario: Each sign-in names its provider, its country and a failed provider
    Given the table sign_ins holds:
      | outcome         | provider | address     | user_agent | browser | os    | city   | country | country_name   | created_at     |
      | signed_in       | google   | 81.2.69.160 | ua         | Chrome  | macOS | London | GB      |                | 1 minute ago   |
      | signed_in       | github   | 81.2.69.160 | ua         | Edge    | macOS | London | GB      | United Kingdom | 2 minutes ago  |
      | provider_failed | google   | 81.2.69.160 | ua         | Opera   | macOS | London | GB      |                | 3 minutes ago  |
      | denied          | github   | 81.2.69.160 | ua         | null    | null  | null   | null    |                | 4 minutes ago  |
    When I visit "/admin/settings/security"
    Then the "Chrome · macOS" row in "Sign-ins" says "Google · London · GB · 81.2.69.160"
    And the "Edge · macOS" row in "Sign-ins" says "London · United Kingdom · 81.2.69.160"
    And the "Opera · macOS" row in "Sign-ins" shows the pink pill "Google failed"
    And the "Unknown device" row in "Sign-ins" says "Unknown place"

  Scenario: A token's sightings show place, calls, address and both times
    Given an API token "Terminal"
    And the table sightings holds:
      | api_token_id                                     | browser | os    | city   | country | calls | last_address | last_user_agent | first_seen_at |
      | (SELECT id FROM api_tokens WHERE name = 'Terminal') | Firefox | Linux | London | GB      | 3     | 81.2.69.160  | Firefox/141     | 1 hour ago    |
    When I visit "/admin/settings/security"
    Then the "Firefox · Linux" row in "Terminal" says "London · GB · 3 calls · 81.2.69.160"
    And the "Firefox · Linux" row in "Terminal" says "first seen"
    And the "Firefox · Linux" row in "Terminal" says "last seen"
    And the "Firefox · Linux" row in "Terminal" shows 2 times

  Scenario: Sightings name their country, an unread device and place, and a bare user agent's product
    Given an API token "Terminal"
    And an MCP client "Claude" with a live token
    And the table sightings holds:
      | api_token_id                                        | oauth_client_id                                           | browser | os    | city   | country | country_name   | calls | last_address | last_user_agent        |
      | (SELECT id FROM api_tokens WHERE name = 'Terminal') |                                                           | Firefox | Linux | London | GB      | United Kingdom | 3     | 81.2.69.160  | Firefox/141            |
      | (SELECT id FROM api_tokens WHERE name = 'Terminal') |                                                           | null    | null  | null   | null    |                | 1     | 81.2.69.160  | ""                     |
      | (SELECT id FROM api_tokens WHERE name = 'Terminal') |                                                           | null    | Linux | London | GB      |                | 1     | 81.2.69.160  | curl/8.7.1             |
      |                                                     | (SELECT id FROM oauth_clients WHERE client_name = 'Claude') | null    | null  | London | GB      |                | 1     | 81.2.69.160  | claude-code/1.2 (cli)  |
    When I visit "/admin/settings/security"
    Then the "Firefox · Linux" row in "Terminal" says "London · United Kingdom · 3 calls"
    And the "Unknown device" row in "Terminal" says "Unknown place"
    And the "curl 8.7.1 · Linux" row in "Terminal" says "1 call"
    And the "Claude" card lists:
      | claude-code 1.2 |

  Scenario: An MCP client's sightings list under that client
    Given an API token "Terminal"
    And an MCP client "Claude" with a live token
    And the table sightings holds:
      | api_token_id                                        | oauth_client_id                                             | browser | os    | last_address | last_user_agent |
      |                                                     | (SELECT id FROM oauth_clients WHERE client_name = 'Claude') | Chrome  | Linux | 81.2.69.160  | Chrome/141      |
      | (SELECT id FROM api_tokens WHERE name = 'Terminal') |                                                             | Firefox | Linux | 81.2.69.160  | Firefox/141     |
    When I visit "/admin/settings/security"
    Then the "Claude" card lists:
      | Chrome · Linux |

  Scenario: A client that registered no name goes by its redirect host
    Given an MCP client "" with a live token
    When I visit "/admin/settings/security"
    Then the page says "claude.ai"

  Scenario: A credential nothing has used says so
    Given an API token "Terminal"
    When I visit "/admin/settings/security"
    Then the "Terminal" card says "Nothing has used it yet."
