# HK Call Blocker / 香港來電封鎖

iPhone app targeting iOS 18.0+ (including 18.7), with English and Traditional Chinese UI, a system-language default and an in-app language picker.

## Build / 建置

Upload the contents of this folder to the **root** of `kakoro-chan/HKCallBlocker`, including the hidden `.github` folder. Do not upload the outer `HKCallBlocker` folder itself. The root should contain `project.yml`, `App`, `Shared`, `Extension`, `Tests`, and `.github/workflows/build.yml`.

Open **Actions → Build iPhone IPA → Run workflow**. After a successful run, download the `HKCallBlocker-unsigned` artifact at the bottom of the run page. Extract the ZIP to obtain `HKCallBlocker-unsigned.ipa` and the required entitlements file. The IPA is **unsigned** and cannot be installed before signing. Build success alone does not verify phone-call blocking.

將本資料夾內的內容上傳至 GitHub 儲存庫根目錄，包括隱藏的 `.github` 資料夾。不要把外層 `HKCallBlocker` 資料夾一併上傳。

在 **Actions → Build iPhone IPA → Run workflow** 執行建置。成功後下載頁面下方的 `HKCallBlocker-unsigned`，解壓縮取得 `.ipa`。此檔案尚未簽署，需要交給全能簽處理。建置成功並不代表已在實機驗證來電封鎖。

## Signing requirement / 簽署要求

The app and embedded Call Directory extension both need provisioning profiles that authorize the SAME App Group:

`group.com.kakorochan.HKCallBlocker`

The signer must preserve the `PlugIns/CallDirectory.appex` extension and sign it separately. An app that launches successfully can still have a nonfunctional extension or inaccessible shared container. This project is not a promise of compatibility with every 全能簽 certificate/profile. If your certificate provider cannot supply profiles with App Groups for both targets, dynamic user-editable call blocking cannot work with this implementation.

主程式及內嵌的來電擴充功能都需要支援上述相同 App Group 的描述檔。全能簽須保留並分別簽署 `PlugIns/CallDirectory.appex`。只有主程式能開啟，不能證明來電封鎖有效。如果現有憑證／描述檔不支援這項能力，必須取得合適的簽署設定才可使用本實作。不要將私人憑證或描述檔上傳公開儲存庫。

If your signing team uses a different group identifier, change `Shared/BlockStore.swift` and `Shared/AppGroups.entitlements` together, then rebuild. If the app bundle ID changes, the extension bundle ID must equal the new app ID plus `.CallDirectory`.

## Use / 使用

1. Install the signed app and extension.
2. Enable HK Call Blocker in Settings → Apps → Phone → Call Blocking & Identification (wording may vary with language).
3. Add `91234567` to mean `+85291234567`; use `+86…` or `0086…` for international numbers. Bare numbers must be exactly 8 digits. Spaces, parentheses and hyphens are ignored.
4. Tap **Apply block list / 套用封鎖名單**. Only a successful iOS reload is reported as loaded. If the extension is disabled or the App Group is inaccessible, the app reports an error.
5. Swipe to delete; tap Apply again. Removing and applying the last entry clears this extension's block list.

Exact full numbers only. No whole-country/prefix blocking, anonymous caller blocking, WhatsApp or FaceTime filtering, SMS filtering, contact access, or call-history monitoring. The caller ID provided to iOS must match the blocked number; this does not prevent caller-ID spoofing. Data is written locally to the shared App Group; no network calls are made by this app. iOS backup may include app data.

## Validation / 驗證

The workflow checks normalization (Hong Kong defaults, explicit international numbers, duplicates and invalid inputs), compiles both iOS targets and confirms the extension is embedded in the IPA. Real-device checks are still required: enable the extension, block a controlled test number, call from that number, remove/apply it and verify calls resume. Repeat after closing the app and switching language. Do not use simulator or build success as evidence of actual call blocking.

## References

- [Apple Call Directory provider](https://developer.apple.com/documentation/callkit/cxcalldirectoryprovider)
- [Apple shared App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Status: source prepared; macOS build and real-device behavior are unverified until the workflow and device checks succeed.
