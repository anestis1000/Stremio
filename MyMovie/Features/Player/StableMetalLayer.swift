import QuartzCore
// Avoid MoltenVK's teardown resize replacing the actual video surface with 1×1.
final class StableMetalLayer: CAMetalLayer {
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set { if newValue.width > 1 && newValue.height > 1 { super.drawableSize = newValue } }
    }
}
