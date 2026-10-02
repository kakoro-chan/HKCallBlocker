import SwiftUI
import CallKit

@main
struct HKCallBlockerApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

enum Language: String, CaseIterable {
    case system, english, traditionalChinese
    var chinese: Bool {
        self == .traditionalChinese || (self == .system && Locale.preferredLanguages.first?.hasPrefix("zh") == true)
    }
    var label: String {
        switch self {
        case .system: return "System / 跟隨系統"
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        }
    }
}

enum Notice {
    case ready, saved, applied, duplicate, invalid, storage, reloadFailed, checking
    func text(_ chinese: Bool) -> String {
        switch self {
        case .ready: return chinese ? "新增號碼後，按「套用封鎖名單」。" : "Add numbers, then tap Apply block list."
        case .saved: return chinese ? "已儲存變更，尚未套用至 iOS。" : "Changes saved; not yet applied to iOS."
        case .applied: return chinese ? "iOS 已成功載入封鎖名單。" : "iOS successfully loaded the block list."
        case .duplicate: return chinese ? "此號碼已在名單內。" : "This number is already on the list."
        case .invalid: return chinese ? "請輸入 8 位香港號碼，或以 +／00 開頭的完整國際號碼。" : "Enter an 8-digit Hong Kong number or a full international number beginning with + or 00."
        case .storage: return chinese ? "無法讀寫共用名單。請檢查主程式及擴充功能的 App Group 簽署設定。" : "Cannot access the shared list. Check App Group signing for both the app and extension."
        case .reloadFailed: return chinese ? "未能套用名單。請先在 iPhone 設定啟用擴充功能，並檢查簽署設定。" : "Could not apply the list. Enable the extension in iPhone Settings and check signing."
        case .checking: return chinese ? "正在套用…" : "Applying…"
        }
    }
}

@MainActor
final class BlockModel: ObservableObject {
    @Published var numbers: [Int64] = []
    @Published var notice: Notice = .ready
    @Published var detail = ""
    @Published var storageOK = false
    @Published var busy = false
    @Published var enabled: Bool? = nil
    private var revision: UUID?
    private var appliedRevision: UUID?

    var hasPendingChanges: Bool { revision != appliedRevision }
    var extensionID: String { (Bundle.main.bundleIdentifier ?? "com.kakorochan.HKCallBlocker") + ".CallDirectory" }

    func load() {
        do {
            let snapshot = try BlockStore.read()
            numbers = snapshot.numbers
            revision = snapshot.revision
            storageOK = true
        } catch { failStorage(error) }
    }

    func add(_ input: String) -> Bool {
        guard storageOK, !busy else { return false }
        do {
            let number = try PhoneNumber.normalize(input)
            guard !numbers.contains(number) else { notice = .duplicate; detail = ""; return false }
            return save(numbers + [number])
        } catch { notice = .invalid; detail = ""; return false }
    }

    func remove(_ offsets: IndexSet) {
        guard storageOK, !busy else { return }
        var changed = numbers
        changed.remove(atOffsets: offsets)
        _ = save(changed)
    }

    private func save(_ changed: [Int64]) -> Bool {
        do {
            let snapshot = try BlockStore.write(changed)
            numbers = snapshot.numbers
            revision = snapshot.revision
            notice = .saved
            detail = ""
            return true
        } catch { failStorage(error); return false }
    }

    private func failStorage(_ error: Error) {
        storageOK = false
        notice = .storage
        detail = String(describing: error)
    }

    func checkStatus() async {
        do {
            let status: CXCallDirectoryManager.EnabledStatus = try await withCheckedThrowingContinuation { continuation in
                CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: extensionID) { status, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: status)
                    }
                }
            }
            enabled = status == .enabled ? true : (status == .disabled ? false : nil)
        } catch { enabled = nil }
    }

    func apply() async {
        guard storageOK, !busy else { return }
        busy = true
        notice = .checking
        detail = ""
        defer { busy = false }
        do {
            try await CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionID)
            appliedRevision = revision
            notice = .applied
        } catch {
            notice = .reloadFailed
            let ns = error as NSError
            detail = "\(ns.domain) (\(ns.code))"
        }
        await checkStatus()
    }
}

struct ContentView: View {
    @StateObject private var model = BlockModel()
    @AppStorage("language") private var language: Language = .system
    @State private var input = ""
    @FocusState private var entering: Bool
    @Environment(\.scenePhase) private var scenePhase
    private var zh: Bool { language.chinese }
    private func t(_ en: String, _ chinese: String) -> String { zh ? chinese : en }

    var body: some View {
        NavigationStack {
            List {
                Section(t("Language", "語言")) {
                    Picker(t("Display language", "顯示語言"), selection: $language) {
                        ForEach(Language.allCases, id: \.self) { item in Text(item.label).tag(item) }
                    }
                }
                Section {
                    Label(t("Local region: Hong Kong (+852)", "本地地區：香港（+852）"), systemImage: "globe")
                    TextField(t("91234567 or +8613800138000", "91234567 或 +8613800138000"), text: $input)
                        .keyboardType(.phonePad)
                        .focused($entering)
                        .accessibilityLabel(t("Phone number", "電話號碼"))
                    Button(t("Add number", "新增號碼")) {
                        if model.add(input) { input = ""; entering = false }
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.storageOK || model.busy)
                } header: { Text(t("Add blocked number", "新增封鎖號碼")) }
                  footer: { Text(t("Without + or 00, enter exactly 8 digits. This blocks individual numbers, not whole countries.", "沒有 + 或 00 時，請輸入 8 位香港號碼。只封鎖指定完整號碼，不會封鎖整個國家。")) }

                Section {
                    HStack {
                        Text(t("Extension", "擴充功能"))
                        Spacer()
                        Text(model.enabled == true ? t("Enabled", "已啟用") : (model.enabled == false ? t("Disabled", "未啟用") : t("Unknown", "未確認")))
                            .foregroundStyle(model.enabled == true ? .green : .secondary)
                    }
                    Text(model.notice.text(zh))
                    if !model.detail.isEmpty { Text(model.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                    if model.hasPendingChanges && model.storageOK {
                        Text(t("Tap Apply to confirm the current list is loaded.", "請按「套用」確認目前名單已載入。"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        entering = false
                        Task { await model.apply() }
                    } label: {
                        Label(t("Apply block list", "套用封鎖名單"), systemImage: "shield.checkered")
                    }
                    .disabled(!model.storageOK || model.busy)
                    if model.busy { ProgressView() }
                    Button(t("Refresh status", "重新檢查狀態")) {
                        model.load()
                        Task { await model.checkStatus() }
                    }.disabled(model.busy)
                } header: { Text(t("Blocking status", "封鎖狀態")) }

                Section {
                    if model.numbers.isEmpty { Text(t("No blocked numbers", "尚未新增封鎖號碼")).foregroundStyle(.secondary) }
                    ForEach(model.numbers, id: \.self) { number in
                        Text("+\(String(number))").monospacedDigit()
                    }.onDelete(perform: model.remove)
                } header: { Text(t("Blocked numbers", "封鎖號碼") + " (\(model.numbers.count))") }
                  footer: { Text(t("Swipe left to delete, then tap Apply. Removing the last number clears this app’s block list.", "向左滑動刪除，再按「套用」。刪除最後一個號碼並套用，會清除此應用程式的封鎖名單。")) }

                Section(t("Setup", "設定說明")) {
                    Text(t("In Settings → Apps → Phone → Call Blocking & Identification, enable HK Call Blocker. Return here and tap Apply.", "在「設定 → App → 電話 → 通話封鎖與識別」啟用 HK Call Blocker，然後返回此處按「套用」。"))
                    Text(t("Numbers stay on your phone. Ordinary incoming phone calls only; no WhatsApp/FaceTime filtering or call-history access.", "號碼保存在手機內。只處理一般電話來電，不處理 WhatsApp／FaceTime，也不讀取通話紀錄。"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(t("HK Call Blocker", "香港來電封鎖"))
            .toolbar { ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(t("Done", "完成")) { entering = false }
            } }
            .task { model.load(); await model.checkStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.checkStatus() } }
            }
        }
        .environment(\.locale, Locale(identifier: zh ? "zh-Hant" : "en"))
    }
}
