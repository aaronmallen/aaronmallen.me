Feature: Content security policy
  Every font face in the site's sheets loads from the site itself.

  Scenario Outline: Every face in <sheet> loads from the site
    When I request "{asset:<sheet>}"
    Then every font face in the sheet loads from the site

    Examples:
      | sheet          |
      | public/app.css |
      | admin/app.css  |
