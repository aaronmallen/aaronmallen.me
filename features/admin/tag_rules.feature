Feature: Tags on task rules
  A task rule keeps at least one tag or project. Postgres refuses to delete the last one, and a rule that files
  into a project holds that project's own tags.

  Background:
    Given the tag manager has the project "blog" keyed "BLOG"

  Scenario: Postgres refuses to delete the only tag on a task rule
    Given the tag manager has a task rule "aaronmallen/*" tagged "ruby"
    Then the database refuses, breaking a check constraint:
      """
      delete from tags where name = 'ruby'
      """

  Scenario: Postgres deletes the only tag on a task rule that holds a project
    Given the tag manager has a task rule "aaronmallen/*" tagged "ruby@BLOG"
    And the tag manager's task rule "aaronmallen/*" files into the project "BLOG"
    When the database runs:
      """
      delete from tags where name = 'ruby'
      """
    Then the database answers "0, 1" for:
      """
      select (select count(*) from tags) as a, (select count(*) from task_rule_projects) as b
      """

  Scenario: Postgres refuses to delete the only project on a task rule with no tags
    Given the tag manager has a task rule "aaronmallen/*" tagged ""
    And the tag manager's task rule "aaronmallen/*" files into the project "BLOG"
    Then the database refuses, breaking a check constraint:
      """
      delete from projects where key = 'BLOG'
      """

  Scenario: Postgres refuses to delete the project of a task rule that holds only that project's tags
    Given the tag manager has a task rule "aaronmallen/*" tagged "ruby@BLOG"
    And the tag manager's task rule "aaronmallen/*" files into the project "BLOG"
    Then the database refuses, breaking a check constraint:
      """
      delete from projects where key = 'BLOG'
      """

  Scenario: A task rule that files into a project holds the project's own tags
    Given I am signed in to the admin
    When I post to the tag manager at "/admin/tasks/rules" with:
      | rule[pattern]    | aaronmallen/* |
      | rule[tags]       | ruby          |
      | rule[projects][] | 1             |
    Then the database answers "ruby, project, 1" for:
      """
      select name, scope, project_id from tags
      """
