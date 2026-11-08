import UIKit
import Metal

final class MPVRenderView: UIView {
    override class var layerClass: AnyClass { StableMetalLayer.self }
    var onReady: ((CAMetalLayer) -> Void)?
    private var attached = false
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let layer = layer as? CAMetalLayer, bounds.width > 1, bounds.height > 1, let window else { return }
        layer.device = layer.device ?? MTLCreateSystemDefaultDevice()
        layer.contentsScale = window.screen.scale
        layer.drawableSize = CGSize(width: bounds.width * window.screen.scale, height: bounds.height * window.screen.scale)
        layer.framebufferOnly = true
        if !attached { attached = true; onReady?(layer) }
    }
}
