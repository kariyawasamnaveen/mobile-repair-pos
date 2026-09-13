# Windows Desktop Build CI

This repository uses GitHub Actions to automatically verify that the Flutter application compiles successfully for the Windows desktop platform.

## What this workflow verifies
- **Compilation Success:** The workflow simply ensures that `flutter build windows --release` finishes successfully without compile-time errors.
- **Dependency Compatibility:** It verifies that native dependencies do not break the Windows build.

## What this workflow DOES NOT verify
- **UI/UX Correctness:** This is a headless compiler check. It does not run automated UI tests, nor does it guarantee that the interface looks correct or behaves properly on a Windows desktop.
- **Runtime Crashes:** Logic errors or exceptions that occur only at runtime on Windows are not caught here.

## How to check the build status
1. Go to the **Actions** tab in your GitHub repository.
2. Look for the workflow named **Windows Desktop Build**.
3. A green checkmark (✅) indicates the code successfully compiles for Windows. A red cross (❌) means the build failed.

## How to download the artifact
If you want to manually test the application on a Windows machine:
1. Go to the **Actions** tab and click on the latest successful run of the **Windows Desktop Build** workflow.
2. Scroll down to the **Artifacts** section at the bottom of the summary page.
3. Click on **windows-build** to download the generated `.zip` file containing the Windows executable (`.exe`) and required `.dll` files.

## Known Limitations & Compatibility Issues
During the initial scaffold, the following dependencies were flagged for potential Windows compatibility issues:
- **`mobile_scanner`**: This package is primarily built for Android, iOS, and macOS. It currently **lacks official Windows support**. When compiling on Windows, this package may cause build failures, or at minimum, the barcode scanning functionality will not work out of the box and might throw unhandled platform exceptions. This will require conditional compilation or a mock implementation if Windows support becomes a priority.
