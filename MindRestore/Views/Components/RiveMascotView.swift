import SwiftUI
import RiveRuntime

enum MascotRiveMood: String {
    case sad = "sad"
    case happy = "happy"
    case neutral = "neutral"
}

private class MascotRiveVM: RiveViewModel {
    private(set) var dataBindingInstance: RiveDataBindingViewModel.Instance?

    var enumProperty: RiveDataBindingViewModel.Instance.EnumProperty? {
        dataBindingInstance?.enumProperty(fromPath: "posesEnum")
    }

    init() {
        super.init(fileName: "memori (1)", stateMachineName: "State Machine 1", artboardName: "Memori")
        riveModel?.enableAutoBind { [weak self] instance in
            self?.dataBindingInstance = instance
        }
    }

    func setPose(_ mood: MascotRiveMood) {
        enumProperty?.value = mood.rawValue
    }
}

struct RiveMascotView: View {
    let mood: MascotRiveMood
    let size: CGFloat

    @StateObject private var viewModel = MascotRiveVM()

    var body: some View {
        viewModel.view()
            .frame(width: size, height: size)
            .task(id: mood) {
                try? await Task.sleep(for: .milliseconds(150))
                viewModel.setPose(mood)
            }
    }
}

#Preview("Happy") {
    RiveMascotView(mood: .happy, size: 200)
}

#Preview("Neutral") {
    RiveMascotView(mood: .neutral, size: 200)
}

#Preview("Sad") {
    RiveMascotView(mood: .sad, size: 200)
}
