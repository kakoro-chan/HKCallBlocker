import CallKit

final class CallDirectoryHandler: CXCallDirectoryProvider {
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        do {
            let snapshot = try BlockStore.read()
            // Reset on incremental requests too: deleting a number must remove its old block.
            if context.isIncremental { context.removeAllBlockingEntries() }
            for number in snapshot.numbers {
                context.addBlockingEntry(withNextSequentialPhoneNumber: number)
            }
            context.completeRequest()
        } catch {
            // Never report success with an empty list if App Group signing is broken.
            context.cancelRequest(withError: error)
        }
    }
}
