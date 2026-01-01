# Offline Database Implementation Walkthrough

This walkthrough details the implementation of the local SQLite database for storing login and signup details.

## Changes Made

1.  **Dependencies Added**:
    -   `sqflite`: For SQLite database operations.
    -   `path`: For handling file paths.

2.  **Files Created**:
    -   `lib/data/local/sqlite_database_helper.dart`: Database helper class to manage SQLite connection, table creation, and user operations.
    -   `lib/data/models/user_model.dart`: Data model representing the user.

3.  **Files Modified**:
    -   `lib/presentation/screens/signup_screen.dart`:
        -   Replaced mock delay with actual database insertion.
        -   Added check for existing email addresses.
        -   Integrated `SqliteDatabaseHelper`.
    -   `lib/presentation/screens/login_screen.dart`:
        -   Replaced mock delay with actual database query.
        -   Integrated `SqliteDatabaseHelper` to verify credentials.
    -   `pubspec.yaml`: Added dependencies.

## How to Test

1.  **Run the App**: Start the application on an emulator or physical device.
    -   Note: For Windows desktop (if applicable), ensure `sqflite_common_ffi` is set up (implementation assumed mobile/standard `sqflite` usage).
2.  **Sign Up**:
    -   Navigate to the "Create an account" screen.
    -   Fill in the details (Name, Email, Phone, Business Name, Password).
    -   Click "Sign Up".
    -   You should see a success message and be redirected to the dashboard.
    -   Try signing up again with the same email; it should fail with "Email already exists".
3.  **Login**:
    -   Restart the app (or log out if implemented).
    -   Navigate to the Login screen.
    -   Enter the email and password you just registered.
    -   Click "Login".
    -   You should be redirected to the dashboard.
    -   Try invalid credentials; it should show an error.

## Database Schema

**Table: `users`**

| Column          | Type    | Constraints |
| :-------------- | :------ | :---------- |
| `id`            | INTEGER | PRIMARY KEY |
| `name`          | TEXT    | NOT NULL    |
| `email`         | TEXT    | NOT NULL    |
| `phone`         | TEXT    | NOT NULL    |
| `business_name` | TEXT    | NOT NULL    |
| `password`      | TEXT    | NOT NULL    |
