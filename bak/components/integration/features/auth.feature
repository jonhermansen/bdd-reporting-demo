Feature: Authentication
  Login, signup, and credential workflows. Each scenario runs the
  Background steps first, exercising the formatter's per-step capture
  with shared setup.

  Background:
    Given a fresh test environment
    And the auth service is reachable

  Scenario: Login with valid credentials
    When the user logs in with "valid" credentials
    Then login is "successful"

  Scenario: Login with invalid credentials
    When the user logs in with "invalid" credentials
    Then login is "rejected"

  Scenario: Sign up new account
    When a new user signs up with email "test@example.com"
    Then a verification email is sent

  Scenario: Reset password
    When the user requests a password reset for "user@example.com"
    Then a reset link is sent

  Scenario: Logout
    Given an authenticated session
    When the user logs out
    Then the session is invalidated
