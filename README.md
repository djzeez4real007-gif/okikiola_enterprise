# Okikiola Enterprise NIG LTD

Inventory, sales, expenses and loss-control app (Android + Web).

## Default logins

| Role | Username | Password |
|------|----------|----------|
| Owner | `owner` | `owner123` |
| Sales staff (sales boy) | `sales` | `sales123` |

**Change these passwords after first login in production.**

## Single sales staff design

- Sales boy can: sell, view products, log expenses, open/close shift
- Sales boy cannot: delete sales, edit cost price, manage users, view full audit/profit
- Max self-discount: 5% (owner/manager unlimited)
- Owner sees everything

## Run

```bash
cd okikiola_enterprise
flutter pub get
flutter run -d chrome
# or
flutter run -d android
```
