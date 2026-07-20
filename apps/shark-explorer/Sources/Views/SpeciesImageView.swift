import SwiftUI
import UIKit

struct SpeciesImageView: View {
    let shark: SharkDefinition
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let image = UIImage(named: shark.imageAsset) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Text(shark.symbol)
                    .font(.system(size: 64))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityLabel("Species image of a \(shark.name)")
    }
}
