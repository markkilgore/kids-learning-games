import SwiftUI
import UIKit

struct SpeciesImageView: View {
    let shark: AnimalDefinition
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let image = UIImage(named: shark.imageAsset) {
                if contentMode == .fill {
                    // Fill the space it is given without growing past it: a very wide photo (the goblin
                    // shark's is nearly 5:1) would otherwise push its container wider than its neighbours.
                    Color.clear
                        .overlay { Image(uiImage: image).resizable().scaledToFill() }
                        .clipped()
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            } else {
                Text(shark.symbol)
                    .font(.system(size: 64))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityLabel("Species image of a \(shark.name)")
    }
}
