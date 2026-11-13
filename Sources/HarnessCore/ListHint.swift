import HarnessProtocol

/// Spots a list that shows only part of its items in what `read` returned, and points to `collect`.
public enum ListHint {
    static let listRoles: Set<String> = ["AXTable", "AXOutline", "AXList", "AXCollectionView", "AXGrid"]

    /// A notice when `node`, or something inside it, is a list in a scroll area with a scroll bar,
    /// so reading it shows only the rows on screen; nil otherwise.
    public static func notice(for node: RawNode) -> Notice? {
        guard scrollingList(in: node) else { return nil }
        return Notice(
            kind: "partialList",
            message: "This reads a scrolling list, which shows only the rows on screen; `collect` scrolls it and returns each item once."
        )
    }

    static func scrollingList(in node: RawNode, depth: Int = 0) -> Bool {
        if node.role == "AXScrollArea", node.children.contains(where: { $0.role == "AXScrollBar" }),
           node.children.contains(where: { listRoles.contains($0.role) }) {
            return true
        }
        guard depth < 40 else { return false }
        return node.children.contains { scrollingList(in: $0, depth: depth + 1) }
    }
}
