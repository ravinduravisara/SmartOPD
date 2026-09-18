# Admin dashboard setup

The existing login screen routes users with role `admin` to the admin dashboard.
Other users keep the existing patient experience. Public registration cannot select
an admin role. Admin API routes verify the current database role on every request.

## First administrator

1. In `backend/.env`, add `ADMIN_NAME`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD` with your own values. Use a new email not already registered as a patient. Passwords require 8–128 characters including uppercase, lowercase, a number, and a symbol. Quote the password in the env file if it includes `#`.
2. From `backend`, run `npm run create-admin` with the normal database configuration available.
3. Remove `ADMIN_PASSWORD` from `.env` after successful setup.
4. Restart the backend and restart the Flutter app. Log in with the email and password you chose.

The setup command inserts a verified admin account with a hashed password. It refuses
to run once an admin exists and never changes an existing account. There are no
hardcoded admin credentials. Creating an admin is an intentional provisioning action
and does not require the public signup email verification flow.

## Additional administrators

Choose **Create new admin** on the dashboard and enter a name, email, password, and
password confirmation. The new admin can immediately log in through the same login
screen. Creating an admin keeps the current administrator signed in. Duplicate emails
are rejected, including emails belonging to patients.

This first increment includes admin login routing, administrator listing, account
creation, refresh, and logout. Staff management and analytics are future work.

Run backend authorization and account creation checks with `npm run test:admin`.
