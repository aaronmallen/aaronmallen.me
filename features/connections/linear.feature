Feature: Linear connection
  I connect Linear workspaces with an API key. The site checks each key with
  Linear before it keeps it, sealed.

  Background:
    Given I am signed in to the admin

  Scenario: The picker opens a key form for Linear under its own mark
    When I visit "/admin/settings/services"
    Then the "Linear" pick in the service picker opens "/admin/settings/services?connect=linear#services"
    And the Linear pick in the service picker shows the Linear mark
    When I visit "/admin/settings/services?connect=linear"
    Then the service panel shows "The site checks these with Linear, then keeps them encrypted."
    And the page has no axe breaches in light or dark

  Scenario: A key Linear takes saves the workspace by name with the key sealed
    Given Linear answers as the workspace "ROOT"
    When I connect Linear with the key " lin_api_root "
    Then the site holds the Linear connections "ROOT"
    And the Linear connection "ROOT" has the account "ws-root" and the scopes ""
    And the Linear connection "ROOT" holds the credentials '{"api_key": "lin_api_root"}'
    And the stored Linear credentials do not hold "lin_api_root"
    And the services address opens the connection "ROOT"
    And the connection toast says "Linear connected as ROOT"
    And the service panel names the account "ROOT"

  Scenario: A key Linear refuses saves nothing and says why
    Given Linear refuses the key with "Authentication required"
    When I connect Linear with the key "lin_api_bad"
    Then the connection answer has status 422
    And the service panel shows the error "Authentication required"
    And the service panel shows "The site checks these with Linear, then keeps them encrypted."
    And the site holds no Linear connection

  Scenario: A blank key saves nothing and never reaches Linear
    When I connect Linear with the key "  "
    Then the service panel shows the error "Paste a key first"
    And Linear received no POST "/graphql"
    And the site holds no Linear connection

  Scenario: A workspace the site already holds saves nothing more
    Given Linear answers as the workspace "ROOT"
    When I connect Linear with the key "lin_api_root"
    And I connect Linear with the key "lin_api_root_again"
    Then the service panel shows the error "That account is already connected"
    And the site holds the Linear connections "ROOT"

  Scenario: A connected workspace offers a test, another account, a disconnect and its dashboard
    Given a Linear connection to "ROOT" with the key "lin_api_root"
    When I open the connection "ROOT"
    Then the service panel offers "Test connection"
    And the service panel links "Add another account" to "/admin/settings/services?connect=linear#services"
    And the service panel offers "Disconnect"
    And the service panel opens "https://linear.app/settings/account/security" in a new tab with no opener
    And the page has no axe breaches in light or dark

  Scenario: A test reports that Linear answers
    Given a Linear connection to "ROOT" with the key "lin_api_root"
    And Linear answers as the workspace "ROOT"
    When I test the connection "ROOT"
    Then the connection toast says "Linear answered"
    And Linear received POST "/graphql" holding "organization"

  Scenario: A test reports that Linear refuses the key
    Given a Linear connection to "ROOT" with the key "lin_api_root"
    And Linear refuses the key with "Authentication required"
    When I test the connection "ROOT"
    Then the connection toast says "Linear isn't answering"
    And the connection toast says "Authentication required"

  Scenario: A disconnect deletes the workspace
    Given a Linear connection to "ROOT" with the key "lin_api_root"
    When I disconnect the connection "ROOT"
    Then the services address is "/admin/settings/services#services"
    And the site holds no Linear connection

  Scenario: A disconnect of a workspace that is gone answers not found
    Given a Linear connection to "ROOT" with the key "lin_api_root"
    When I disconnect the connection "ROOT" after it is gone
    Then the connection answer has status 404
