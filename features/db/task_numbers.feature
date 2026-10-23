Feature: Task numbers
  The database numbers tasks from 1 within each project, and among tasks with no project, and never hands a
  number out twice in one scope.

  Background:
    Given the database runs:
      """
      insert into projects (name, visibility, key) values ('pod', 'public', 'POD'), ('com', 'public', 'COM')
      """

  Scenario: Tasks number from 1 within each project and among tasks with no project
    Given the database runs:
      """
      insert into tasks (title, list, position, project_id) values ('task', 'next', 1, 1);
      insert into tasks (title, list, position, project_id) values ('task', 'next', 1, 2);
      insert into tasks (title, list, position, project_id) values ('task', 'next', 1, null);
      insert into tasks (title, list, position, project_id) values ('task', 'next', 1, 1);
      insert into tasks (title, list, position, project_id) values ('task', 'next', 1, null);
      """
    Then the task numbers in id order are "1, 1, 1, 2, 2"

  Scenario: A number given on insert is ignored
    Given the database runs:
      """
      insert into tasks (title, list, position, project_id) values ('task', 'next', 1, 1);
      insert into tasks (title, list, position, project_id, number) values ('task', 'next', 1, 1, 1);
      """
    Then the task numbers in id order are "1, 2"

  Scenario: A task captured in the admin takes the next number among tasks with no project
    Given the database runs:
      """
      insert into tasks (title, list, position) values ('task', 'next', 1)
      """
    And I am signed in to the admin
    When I capture the task "one" in the admin
    Then the page has no axe breaches in light or dark
    And the database answers "2" for:
      """
      select number from tasks where title = 'one'
      """

  Scenario: Two tasks in one scope cannot share a number
    Given the database runs:
      """
      insert into tasks (title, list, position) values ('task', 'next', 1), ('task', 'next', 1)
      """
    Then the database refuses, breaking a unique constraint:
      """
      update tasks set number = 2 where id = 1
      """

  Scenario Outline: A task keeps or takes a number as its project changes
    Given the database runs:
      """
      insert into tasks (title, list, position, project_id) values ('first', 'next', 1, <first>);
      insert into tasks (title, list, position, project_id) values ('moved', 'next', 1, <from>);
      update tasks set project_id = <to>, title = 'moved' where id = 2;
      """
    Then the database answers "<number>" for:
      """
      select number from tasks where id = 2
      """

    Examples:
      | case                                              | first | from | to   | number |
      | moved to another project takes the next there     | 2     | 1    | 2    | 2      |
      | losing its project takes the next with no project | null  | 1    | null | 2      |
      | an update that leaves the project alone           | 1     | 1    | 1    | 2      |

  Scenario Outline: A number a task gave up is never handed out again in its old scope
    Given the database runs:
      """
      insert into tasks (title, list, position, project_id) values ('first', 'next', 1, <scope>);
      insert into tasks (title, list, position, project_id) values ('gone', 'next', 1, <scope>);
      <leave>;
      insert into tasks (title, list, position, project_id) values ('new', 'next', 1, <scope>);
      """
    Then the database answers "3" for:
      """
      select number from tasks where title = 'new'
      """

    Examples:
      | case                         | scope | leave                                  |
      | deleted from a project       | 1     | delete from tasks where id = 2         |
      | moved out of a project       | 1     | update tasks set project_id = 2 where id = 2 |
      | deleted with no project      | null  | delete from tasks where id = 2         |
      | moved out of having none     | null  | update tasks set project_id = 1 where id = 2 |

  Scenario: Two tasks created at once in one project get different numbers
    When two tasks in the project "POD" are created at once
    Then the task numbers are "1, 2" in some order
