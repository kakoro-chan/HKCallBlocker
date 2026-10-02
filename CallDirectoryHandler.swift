import CallKit

final class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        do {
            let snapshot = try BlockStore.read()
            // Reset on incremental requests too: deleting a number must remove its old block.
            if context.isIncremental { context.removeAllBlockingEntries() }
            for entry in snapshot.entries {
                context.addBlockingEntry(withNextSequentialPhoneNumber: entry.number)
            }
            context.completeRequest()
        } catch {
            // Never report success with an empty list if App Group signing is broken.
            context.cancelRequest(withError: error)
        }
    }
}
