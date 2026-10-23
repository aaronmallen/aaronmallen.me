Feature: Admin saved views list for the palette
  The admin hands the command palette every saved view as JSON: its name, its screen and the address that opens it.

  Scenario: The list gives each view by name with its screen and address, kept out of caches
    Given I am signed in to the admin
    And a saved view "Drafts" on the posts screen with the filters:
      """
      {"status": "draft"}
      """
    And a saved view "Shipped" on the activity screen with the filters:
      """
      {"q": "ship", "types": {"post": "1"}}
      """
    And a saved view "Everything" on the tasks screen
    When I fetch the saved views list for the palette
    Then the saved views list answers 200 with the type "application/json"
    And the saved views list's header "Cache-Control" is "private, no-store"
    And the saved views list's rows are:
      """
      [
        {"id": 2, "title": "Shipped", "screen": "activity", "href": "/admin/activity?types%5Bpost%5D=1&q=ship"},
        {"id": 1, "title": "Drafts", "screen": "posts", "href": "/admin/posts?status=draft"},
        {"id": 3, "title": "Everything", "screen": "tasks", "href": "/admin/tasks"}
      ]
      """

  Scenario: The list leaves a filter the screen no longer knows out of the address
    Given I am signed in to the admin
    And a saved view "Old" on the posts screen with the filters:
      """
      {"status": "draft", "sort": "oldest"}
      """
    When I fetch the saved views list for the palette
    Then the saved views list's rows are:
      """
      [{"id": 1, "title": "Old", "screen": "posts", "href": "/admin/posts?status=draft"}]
      """

  Scenario: The list is empty with no view saved
    Given I am signed in to the admin
    When I fetch the saved views list for the palette
    Then the saved views list's rows are:
      """
      []
      """

  Scenario: The list answers 401 signed out rather than sending me to sign in
    When I fetch the saved views list for the palette signed out
    Then the saved views list answers 401 without sending me anywhere
