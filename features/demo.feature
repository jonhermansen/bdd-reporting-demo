Feature: Synthetic test suite
  Every scenario has a chance of failure, controlled by
  probability. Run with --retry to surface flaky tests.

  @flaky
  Scenario: Login flow
    Given a service
    When the login flow runs
    Then it completes

  @flaky
  Scenario: Search query
    Given a service
    When a search runs
    Then it completes

  @flaky
  Scenario: Checkout
    Given a service
    When checkout runs
    Then it completes

  @flaky
  Scenario: File upload
    Given a service
    When a file upload runs
    Then it completes

  @flaky
  Scenario: Report generation
    Given a service
    When report generation runs
    Then it completes

  @flaky
  Scenario: Notification dispatch
    Given a service
    When notification dispatch runs
    Then it completes

  @flaky
  Scenario: Data sync
    Given a service
    When data sync runs
    Then it completes

  @flaky
  Scenario: Cache warmup
    Given a service
    When cache warmup runs
    Then it completes
