import Perception
import SwiftUI
import NavigationBackport

extension View {
    /// @brief Item navigation on iOS 15. Dismissing the destination clears the source binding.
    @ViewBuilder func nbNavigationDestination<Item, Destination: View>(
        item: Binding<Item?>, @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        nbNavigationDestination(isPresented: Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )) {
            WithPerceptionTracking {
                if let value = item.wrappedValue { destination(value) }
            }
        }
    }
}
