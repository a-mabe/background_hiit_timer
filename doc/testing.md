# Testing Documentation

This document outlines the testing strategy for this app, covering both automated integration tests and manual QA tests. The goal is to ensure that core functionality works as expected across platforms, and that audio features perform reliably on both Android and iOS.

---

## Table of Contents
- [Integration Tests](#integration-tests)
- [Manual QA Tests](#manual-qa-tests)
- [Running Tests](#running-tests)

---

## Integration Tests

Integration tests focus on verifying the main functionality of the app, ensuring that critical features work as expected. These tests are automated and run during the CI/CD pipeline to catch issues early.

### 1. Timer Functionality
- **Description**: Validates the timer states (e.g., "Get ready," "Warmup," "Work").
- **Tests**:
  - The timer transitions through all states without error.
  - Timer pauses, resumes, and resets accurately.
  - Skip interval controls function as expected.
- View the [Test workflow here](https://github.com/a-mabe/background_hiit_timer/actions/workflows/test.yaml).

---

## Manual QA Tests

Some audio functionalities require manual testing, particularly those involving interactions with other applications and background playback. These tests ensure a seamless experience across platforms.

Ideally, each of these tests are performed on both iOS and Android.

### Audio Playback QA Tests

#### Test 1: Audio Playback without Interrupting Other Apps
- **Objective**: Verify that app audio does not stop or interfere with audio from other applications.
- **Steps**:
  1. Start playing music or a podcast on an external app (e.g., Spotify, Apple Music).
  2. Open the app under test and initiate audio playback.
  3. Verify that external audio continues playing and that app audio can be heard simultaneously.
- **Pass Criteria**:
  - App audio and external audio both play uninterrupted.

#### Test 2: Background Audio Playback
- **Objective**: Verify that app audio continues to play in the background for an extended period.
- **Steps**:
  1. Open the app and start a long interval timer.
  2. Minimize the app and leave it in the background for 5 minutes.
  3. After 5 minutes, confirm that the audio is still playing.
- **Pass Criteria**:
  - Audio continues playing for at least 5 minutes without returning to the app.

---

## Running Tests

### Automated Integration Tests

Integration tests will run automatically when a PR is opened. To run manually:

1. Ensure you have all necessary dependencies installed.
2. Run integration tests with the following command:
   ```bash
   flutter drive
   ```
3. Confirm that all tests pass with no errors.

### Manual QA Tests

When contributing, please list what manual QA tests you were able to perform and please list device model, OS version, and any issues observed. It is not a requirement to perform all QA tests on each OS. Whatever tests you can perform are appreciated.
