# Changelog

All notable changes to Pixel Pocket are documented here. Newest release first.

Pixel Pocket is local-first: the on-device Drift/SQLite database is the source of truth and the app works fully offline. Google Sheets is an optional backup target, never a live database.

---

## 1.0.5 — unreleased

Covers everything merged after 1.0.4. This release is mostly a visual refresh: a new navigation bar, a terminal-style PIN lock, and a new app icon. It also fixes stale Home and Chart data after saving a transaction, and stops Android from bringing back an old copy of the app's data after a reinstall. There is no database schema change and no new permission.

### Added

**Icon-only navigation bar with a global add button**

- The bottom bar shows four icon-only tabs (Home, Transactions, Chart, Settings) with a **+** button in the middle that adds a transaction from any tab. It replaces the add button that only the Transactions tab had.
- Tab names are no longer drawn. Long-press a tab to see its name; screen readers still announce every tab and which one is selected.
- A blinking `_` cursor marks the active tab. With *Reduce Motion* on, it stays solid.
- The new transaction's date follows where you are: on the Transactions tab it uses the range you are looking at, and on any other tab it defaults to today.
- The bar keeps room around its icons on every device: 90 pt on iPhones with Face ID, and 80 dp where the system reports no bottom inset, such as Android phones using gesture navigation, so the icons never sit flush against the swipe area.
- Lists scroll fully clear of the bar, so the last item is never hidden behind it, and full-screen error messages stay centred in the part of the screen you can see.

**Retro-terminal PIN screens**

Unlock and Create PIN now read like a terminal session: a `PIXEL_POCKET` header, `>` status lines, a `PIN: ■ ■ ▮ _` prompt with a blinking block cursor, faint scanlines, and an outlined keypad that lights up when pressed.

- A wrong PIN prints `> ACCESS DENIED` and how many attempts are left.
- After six wrong attempts, `> SYSTEM LOCKED: 30s` counts down and the **Forgot PIN?** link from 1.0.4 appears as `> [ FORGOT PIN? ]`.
- Creating a PIN marks the first entry with ✓ and asks you to re-enter it. A mismatch prints `> PIN MISMATCH. START OVER`.
- Only the look changed. The PIN is still 4 digits, with the same 6-attempt limit and 30-second lockout.

**New app icon**

The icon and splash screen are now a pixel-art `~$_` terminal prompt, replacing `~$`. It is used for the launcher icon on iOS and Android, the native splash, and the in-app splash.

### Changed

- **Sheets cover the navigation bar** and animate more gently (420 ms to open, 280 ms to close). While a sheet is open, **+** cannot open a second one, and form validation messages appear above the sheet.
- **Long button labels shrink to fit** instead of overflowing their button.
- **The dashboard lock button** draws its icon dark on the orange button so it is easier to see.

### Fixed

- **Home and Chart showed stale numbers after saving a transaction.** Both tabs stay alive in the background, so after adding a transaction on the Transactions tab they kept showing the old totals. The dashboard summary, the recent list, and the chart now refresh as soon as a transaction is created, edited, or deleted.
- **Reinstalling on Android brought back an old copy of the app's data.** Android's own backup saved a snapshot of the app to the Google account, at most once a day, and restored it on reinstall. The result was a mix that matched no real moment: Google Sheets shown as connected but expired, custom categories from days earlier, and none of the recent transactions. Clearing app data or disconnecting first did not help, because the snapshot lives in the Google account rather than on the phone. Android backup and device-to-device transfer are now turned off for Pixel Pocket, so a reinstall always starts clean. This is Android's system backup only: Pixel Pocket's own **Auto-backup** to Google Sheets still runs about 10 seconds after every change, exactly as before.

### Upgrade notes

- **No migration.** The database schema and stored preferences are unchanged, and the PIN carries over.
- **On Android, a reinstall or a new phone now starts empty.** Google Sheets is the only way to carry data across: run **Backup Now** before, then **Connect** and **Restore** after. A snapshot Android saved before this update may still sit in the Google account, but this version never restores it.
- **Already hit the stale restore?** Updating does not clean up data that Android restored earlier, because it is already on the phone. If Settings shows Google Sheets as connected but backups fail as expired, tap **Disconnect**, then **Connect**, then choose **Restore** in the **Backup found** dialog. Do not tap **Backup Now** before restoring: it would overwrite the sheet with the near-empty data on the phone.
- **iOS may show the old `~$` splash once after updating.** iOS caches the launch screen. It is replaced after the app has been opened.
- **Known limitation:** the Android launcher icon is still a legacy icon, not an adaptive one, so some launchers draw it smaller and inside a white circle.
- **Known limitation:** when Google authorization has expired, auto-backup keeps failing and Settings only shows `⚠ Changes not backed up yet`, without saying that a reconnect is needed.

### Store listing blurb

> **A fresh look.** New icon-only navigation with a + button on every screen, a terminal-style PIN lock, and a new `~$_` app icon.
>
> Also: Home and Chart now update as soon as you save a transaction, and reinstalling on Android no longer brings back an old copy of your data.

---

## 1.0.4 — 2026-08-08

Merged to `main` on 2026-08-08. Two user-visible features land in this release: PIN recovery, and a guard that stops auto-backup from destroying a cloud backup after a reinstall.

### Added

**Forgot PIN recovery**

The PIN is the app's only lock, and the app has no server-side identity to verify ownership against. The only recovery that does not weaken the PIN is a full local wipe — losing the PIN is losing the key to the safe.

- A **"Forgot PIN?"** link now appears on the unlock screen, but only while the 30-second lockout is active (after 6 consecutive wrong attempts). The delay is deliberate friction, so it is not a reflex tap for someone who still remembers their PIN.
- It opens a dedicated **Forgot PIN** screen rather than a small dialog, because the action is destructive and needs room to explain itself. Confirmation requires typing `DELETE`; the erase button stays disabled until the input matches exactly.
- Erasing removes every transaction, category, and salary period, reseeds the 18 default categories, clears the PIN, and disconnects Google Sheets backup. You are then taken through **Create PIN**, exactly as on a fresh install, and land on an empty dashboard.
- Disconnecting backup during the reset is deliberate: it stops auto-backup from silently overwriting the cloud spreadsheet with the data you just erased. Recovering that data afterwards is a manual **Restore** from Settings, once a new PIN is set.

**Restore decision guard for Google Sheets backup**

Connecting to Google never restored anything, while auto-backup defaults to on. After a reinstall, connecting and then adding a single transaction was enough for a 10-second debounced auto-backup to clear every tab and rewrite it from a nearly empty local database. The backup is a full overwrite and is not versioned, so the cloud data was gone permanently.

- Connecting now inspects the spreadsheet first. If it already holds data, a **Backup found** dialog offers **Restore** or **Keep Local**, showing how many transactions are waiting in Drive.
- **Auto-backup is held** from the moment you connect until you decide. Dismissing the dialog does not lift the hold — the decision persists across app restarts and reappears as a warning banner in Settings, in place of the usual "Synced" row.
- Three explicit actions lift the hold: a successful **Restore**, a successful **Backup Now** (which means you deliberately chose to overwrite), or **Keep Local**.
- If the inspection itself fails — offline, quota, a corrupt Metadata tab — the guard closes anyway rather than opening. Holding auto-backup on a sheet we could not read is always safer than overwriting it.

### Changed

- Backup and Settings copy is now English throughout, matching the rest of the app. Affects the auto-backup status row, the restore confirmation, and error messages.
- The restore confirmation and the new decision dialog no longer stack two confirmations: the decision dialog's own text is the warning, so its **Restore** runs immediately. The standalone **Restore** button in Settings still confirms first.

### Fixed

- **Auto-backup could destroy a populated cloud backup during connect.** The app was marked as connected several network round trips before the guard was raised, leaving a window where the debounce timer could fire and overwrite the sheet. The guard is now raised first, and lowered only once inspection confirms the sheet is genuinely empty.
- **An all-zero Metadata tab was trusted over the actual data.** A backup that wrote the data tabs but died before writing Metadata would report `0/0/0` and be treated as empty, clearing the guard. Emptiness is now confirmed against the real rows, matching what Restore itself considers empty.
- **The wrong button showed a loading spinner.** Any in-flight action spun **Backup Now**, so restoring or disconnecting looked like a backup was running. Each button now spins only for its own action.
- **Disconnect could leave stale local metadata** if Google sign-out failed. The spreadsheet id, account email, and backup flags are now cleared regardless.
- **The forgot-PIN wipe was not atomic.** A partial failure could leave the database half-erased. The wipe now runs in a single transaction.
- **A failed reset could strand you mid-recovery.** If the wipe fails, the PIN and lock state are left untouched so you can retry, and the error message explains what happened.
- **`/reset-pin` was reachable while already signed in.** It now bounces to the dashboard.

### Upgrade notes

- **Existing users who are already connected see no change.** The guard has no stored value for them, which reads as "not held", so auto-backup keeps working exactly as before. There is no preferences migration and no database schema change.
- **Disconnecting and reconnecting now prompts.** That is intended — reconnecting is exactly when the app cannot tell whether local or cloud data is the one you want to keep.
- Recovering data after a forgot-PIN wipe requires a Google Sheets backup that was made *before* the wipe. There is no other recovery path; this is a consequence of the app being fully offline with no server-side identity.

---

## Store listing blurb (1.0.4)

Short enough for the Play Store / App Store "What's new" field:

> **Forgot your PIN?** You can now reset it from the unlock screen. Recovery erases the data on this device, so restore from your Google Sheets backup afterwards.
>
> **Safer backups.** Connecting to Google now checks whether your spreadsheet already holds data and asks whether to restore it or keep what is on this phone. Auto-backup waits for your answer instead of overwriting the backup.
>
> Also: the loading spinner now appears on the button you actually pressed, and backup screens are in English throughout.

---

## Earlier releases

Versions 1.0.1 through 1.0.3 were bumped on `dev` during development and were not released from `main` separately; their changes are folded into 1.0.4 above. No git tags exist yet — consider tagging `v1.0.4` when this ships so future entries have a firm boundary.
