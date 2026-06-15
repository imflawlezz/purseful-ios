import SwiftData
import SwiftUI

extension View {
    func withPreviewDependencies() -> some View {
        let container = ModelContainerProvider.preview
        let dependencies = DependencyContainer(context: container.mainContext)
        return modelContainer(container)
            .environment(dependencies)
    }
}
