import SwiftUI
import UIKit
import Metal

struct MPVVideoSurface: UIViewRepresentable {
    let model: PlaybackModel
    func makeUIView(context: Context) -> MPVRenderView {
        let view = MPVRenderView(); view.backgroundColor = .black
        view.onReady = { [weak model] layer in model?.attach(to: layer) }
        return view
    }
    func updateUIView(_ uiView: MPVRenderView, context: Context) { }
}
