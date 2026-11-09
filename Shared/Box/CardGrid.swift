import SwiftUI

/// Equal cards in rows, filled from the top left. Every card is laid out up
/// front. A lazy grid can't be used here: on iOS 27.2 a card dropped into one
/// leaves its slot blank for a moment before it appears.
struct CardGrid: SwiftUI.Layout {
    let columns: Int
    let spacing: CGFloat
    /// Width over height for one card.
    let aspectRatio: CGFloat

    /// Where the card at `index` sits in a grid this wide, measured from the
    /// grid's top left corner.
    func frame(at index: Int, inWidth width: CGFloat) -> CGRect {
        let columns = max(columns, 1)
        let gaps = spacing * CGFloat(columns - 1)
        let cardWidth = max(width - gaps, 0) / CGFloat(columns)
        let cardHeight = cardWidth / aspectRatio
        return CGRect(
            x: CGFloat(index % columns) * (cardWidth + spacing),
            y: CGFloat(index / columns) * (cardHeight + spacing),
            width: cardWidth,
            height: cardHeight
        )
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        guard let last = subviews.indices.last else { return CGSize(width: width, height: 0) }
        return CGSize(width: width, height: frame(at: last, inWidth: width).maxY)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, card) in subviews.enumerated() {
            let frame = frame(at: index, inWidth: bounds.width)
                .offsetBy(dx: bounds.minX, dy: bounds.minY)
            card.place(at: frame.origin, proposal: ProposedViewSize(frame.size))
        }
    }
}

extension Array where Element: Identifiable {
    /// This array after some of its elements are picked up and set down
    /// together just before `anchor`, or at the end when there is none. They
    /// land in the order they were picked up.
    func placing(_ picked: [Element.ID], before anchor: Element.ID?) -> [Element] {
        let lifted = Set(picked)
        var carried: [Element.ID: Element] = [:]
        var result: [Element] = []
        result.reserveCapacity(count)
        var gap: Int?
        var passedAnchor = false

        for element in self {
            if let anchor, element.id == anchor { passedAnchor = true }
            if lifted.contains(element.id) {
                carried[element.id] = element
            } else {
                // An anchor that was itself picked up hands over to the next
                // element left in place.
                if passedAnchor, gap == nil { gap = result.count }
                result.append(element)
            }
        }

        let group = picked.compactMap { carried.removeValue(forKey: $0) }
        result.insert(contentsOf: group, at: gap ?? result.count)
        return result
    }
}
