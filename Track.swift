import Foundation
import SwiftUI

struct Track: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
    let url: URL
    let accentColor: Color
}
