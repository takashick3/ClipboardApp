import SwiftUI

enum FontSizeScale: String, CaseIterable {
    case small  = "small"
    case medium = "medium"
    case large  = "large"

    var label: String {
        switch self {
        case .small:  return "小"
        case .medium: return "中"
        case .large:  return "大"
        }
    }

    var rowFont: Font {
        switch self {
        case .small:  return .footnote
        case .medium: return .body
        case .large:  return .title3
        }
    }

    var rowVerticalPadding: CGFloat {
        switch self {
        case .small:  return 4
        case .medium: return 6
        case .large:  return 9
        }
    }
}
