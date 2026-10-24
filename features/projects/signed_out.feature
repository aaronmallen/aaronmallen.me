Feature: Project screens signed out
  The project screens answer a visitor who is not signed in without showing anything.

  Scenario: The project choices answer 401 when signed out
    When I fetch the admin page "/admin/projects/choices" as JSON
    Then the server answers 401
