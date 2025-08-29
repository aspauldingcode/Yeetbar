import Cocoa
import ObjectiveC.runtime

private var originalImps: [Selector: IMP] = [:]
private var titlebarContainerViewKey: UnsafeRawPointer? = nil

@_cdecl("yeetbar_swift_init")
public func yeetbar_swift_init() {
    DispatchQueue.main.async {
        let window = NSWindow.self
        let view = NSView.self
        
        let windowSelectors: [(original: Selector, swizzled: Selector)] = [
            (#selector(NSWindow.makeKeyAndOrderFront(_:)), #selector(NSWindow.yeetbar_makeKeyAndOrderFront(_:))),
            (#selector(NSWindow.orderFront(_:)), #selector(NSWindow.yeetbar_orderFront(_:))),
            (#selector(NSWindow.setFrame(_:display:)), #selector(NSWindow.yeetbar_setFrame(_:display:))),
            (#selector(NSWindow.setFrame(_:display:animate:)), #selector(NSWindow.yeetbar_setFrame(_:display:animate:)))
        ]
        
        for (orig, swiz) in windowSelectors {
            originalImps[orig] = class_getMethodImplementation(window, orig)
            swizzle(window, orig, swiz)
        }
        
        swizzle(view, #selector(NSView.layout), #selector(NSView.yeetbar_layout))
        swizzle(view, #selector(NSView.layoutSubtreeIfNeeded), #selector(NSView.yeetbar_layoutSubtreeIfNeeded))
    }
}

func swizzle(_ cls: AnyClass, _ orig: Selector, _ swiz: Selector) {
    guard let origMethod = class_getInstanceMethod(cls, orig),
          let swizMethod = class_getInstanceMethod(cls, swiz) else { return }
    
    if class_addMethod(cls, orig, method_getImplementation(swizMethod), method_getTypeEncoding(swizMethod)) {
        class_replaceMethod(cls, swiz, method_getImplementation(origMethod), method_getTypeEncoding(origMethod))
    } else {
        method_exchangeImplementations(origMethod, swizMethod)
    }
}

extension NSView {
    @objc func yeetbar_layout() {
        yeetbar_layout()
        if String(describing: type(of: self)).contains("NSTitlebar") {
            window?.yeet()
        }
    }
    
    @objc func yeetbar_layoutSubtreeIfNeeded() {
        yeetbar_layoutSubtreeIfNeeded()
        if String(describing: type(of: self)).contains("NSTitlebar") {
            window?.yeet()
        }
    }
}

extension NSWindow {
    
    private var titlebarContainerView: NSView? {
        get {
            return objc_getAssociatedObject(self, &Self.titlebarContainerViewKey) as? NSView
        }
        set {
            objc_setAssociatedObject(self, &Self.titlebarContainerViewKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    private static var titlebarContainerViewKey = 0
    private static var originalParentKey = 0
    
    // Cleanup method to remove observers and prevent memory leaks
    private func cleanupYeetbarObservers() {
        NotificationCenter.default.removeObserver(self, name: NSWindow.willEnterFullScreenNotification, object: self)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didExitFullScreenNotification, object: self)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: self)
    }
    
    // Override dealloc equivalent for cleanup
    @objc private func yeetbar_windowWillClose(_ notification: Notification) {
        cleanupYeetbarObservers()
    }
    
    @objc func yeetbar_makeKeyAndOrderFront(_ sender: Any?) {
        if let imp = originalImps[#selector(NSWindow.makeKeyAndOrderFront(_:))] {
            let original = unsafeBitCast(imp, to: (@convention(c) (NSWindow, Selector, Any?) -> Void).self)
            original(self, #selector(NSWindow.makeKeyAndOrderFront(_:)), sender)
        }
        yeet()
    }
    
    @objc func yeetbar_orderFront(_ sender: Any?) {
        if let imp = originalImps[#selector(NSWindow.orderFront(_:))] {
            let original = unsafeBitCast(imp, to: (@convention(c) (NSWindow, Selector, Any?) -> Void).self)
            original(self, #selector(NSWindow.orderFront(_:)), sender)
        }
        yeet()
    }
    
    @objc func yeetbar_setFrame(_ frame: NSRect, display: Bool) {
        if let imp = originalImps[#selector(NSWindow.setFrame(_:display:))] {
            let original = unsafeBitCast(imp, to: (@convention(c) (NSWindow, Selector, NSRect, Bool) -> Void).self)
            original(self, #selector(NSWindow.setFrame(_:display:)), frame, display)
        }
        yeet()
    }
    
    @objc func yeetbar_setFrame(_ frame: NSRect, display: Bool, animate: Bool) {
        if let imp = originalImps[#selector(NSWindow.setFrame(_:display:animate:))] {
            let original = unsafeBitCast(imp, to: (@convention(c) (NSWindow, Selector, NSRect, Bool, Bool) -> Void).self)
            original(self, #selector(NSWindow.setFrame(_:display:animate:)), frame, display, animate)
        }
        yeet()
    }

    private func disableTitlebar() {
        // Skip titlebar modification during fullscreen transitions to prevent crashes
        guard !isInFullscreenTransition() else {
            // Schedule retry after transition completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.yeet()
            }
            return
        }
        
        // Additional safety check - don't modify if window is not ready
        guard contentView != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.yeet()
            }
            return
        }
        
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        styleMask.insert(.fullSizeContentView)
        isMovableByWindowBackground = true
        
        // Hide traffic lights
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        // Safely hide titlebar without removing essential views
        hideTitlebarSafely()
        
        // Add fullscreen state monitoring for crash prevention
        setupFullscreenMonitoring()
    }
    
    private func hideTitlebarSafely() {
        guard let contentView = contentView else { return }
        
        // Only hide titlebar views without relocating to prevent crashes
        hideTitlebarViews(in: contentView)
        
        // Use window properties to minimize titlebar space
        minimizeTitlebarSpace()
    }
    
    private func hideTitlebarViews(in view: NSView) {
        for subview in view.subviews {
            let typeName = String(describing: type(of: subview))
            
            if typeName.contains("NSTitlebarView") {
                // Hide the titlebar but don't remove it
                subview.isHidden = true
                
                // Try to minimize its frame height
                var frame = subview.frame
                frame.size.height = 0
                subview.frame = frame
            } else if typeName.contains("NSTitlebarContainerView") {
                // Store reference to titlebar container for fullscreen handling
                titlebarContainerView = subview
                
                if styleMask.contains(.fullScreen) {
                    // In fullscreen, move container to superview to keep UI elements accessible
                    moveContainerToSuperview(subview)
                } else {
                    // Hide container but keep it in hierarchy
                    subview.isHidden = true
                    
                    // Minimize its height
                    var frame = subview.frame
                    frame.size.height = 0
                    subview.frame = frame
                }
            }
            
            // Recursively process subviews
            hideTitlebarViews(in: subview)
        }
    }
    
    private func minimizeTitlebarSpace() {
        // Use window properties to minimize titlebar impact without breaking view hierarchy
        
        // Ensure titlebar is as small as possible
        if responds(to: Selector(("setTitlebarHeight:"))) {
            perform(Selector(("setTitlebarHeight:")), with: 0)
        }
        
        // Try to set toolbar height to minimal
        if let toolbar = toolbar {
            toolbar.isVisible = false
        }
        
        // Ensure content uses maximum available space
        if let contentView = contentView {
            contentView.wantsLayer = true
            contentView.needsLayout = true
        }
    }
    
    private func adjustScrollViewInsets(in view: NSView, topInset: CGFloat) {
        if let scrollView = view as? NSScrollView {
            scrollView.automaticallyAdjustsContentInsets = false
            var insets = NSEdgeInsetsZero
            insets.top = topInset
            scrollView.contentInsets = insets
            scrollView.scrollerInsets = insets
        }
        
        for subview in view.subviews {
            adjustScrollViewInsets(in: subview, topInset: topInset)
        }
    }
    
    private func getTitlebarHeight() -> CGFloat {
        let dummyContentRect = NSRect(x: 0, y: 0, width: 100, height: 100)
        let dummyWindowRect = NSWindow.frameRect(forContentRect: dummyContentRect, styleMask: styleMask)
        return max(dummyWindowRect.height - dummyContentRect.height, 28) // Minimum 28pt
    }
    
    // Fullscreen crash prevention methods
    private func isInFullscreenTransition() -> Bool {
        // Check if window is currently transitioning to/from fullscreen
        if styleMask.contains(.fullScreen) {
            return false // Already in fullscreen, safe to modify
        }
        
        // Check for transition states that could cause crashes
        let isTransitioning = (styleMask.rawValue & 0x4000) != 0 // NSWindowStyleMaskFullScreenWindow
        
        // Additional safety checks
        let hasFullScreenAuxiliary = (styleMask.rawValue & 0x8000) != 0
        let isAnimating = responds(to: Selector(("isInFullScreenTransition"))) && 
                         perform(Selector(("isInFullScreenTransition"))).takeUnretainedValue().boolValue
        
        return isTransitioning || hasFullScreenAuxiliary || isAnimating
    }
    
    private func setupFullscreenMonitoring() {
        // Clean up any existing observers first
        cleanupYeetbarObservers()
        
        // Monitor fullscreen state changes to prevent crashes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willEnterFullScreenNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.handleFullscreenWillEnter()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.handleFullscreenDidExit()
        }
        
        // Monitor window close for cleanup
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.cleanupYeetbarObservers()
        }
    }
    
    private func handleFullscreenWillEnter() {
        // Don't modify titlebar during transition to prevent crashes
        // Just prepare for post-transition handling
        
        // Schedule titlebar container relocation after fullscreen transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.styleMask.contains(.fullScreen) {
                self.handleFullscreenContainerRelocation()
            }
        }
    }
    
    private func handleFullscreenDidExit() {
        // Restore container to original position and re-apply titlebar hiding
        restoreContainerFromSuperview()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.yeet()
        }
    }
    
    private func handleFullscreenContainerRelocation() {
        guard let container = titlebarContainerView else { return }
        moveContainerToSuperview(container)
    }
    
    private func moveContainerToSuperview(_ container: NSView) {
        guard let contentView = contentView,
              let superview = contentView.superview,
              container.superview != superview else { return }
        
        // Store original parent for restoration
        let originalParent = container.superview
        
        // Remove from current parent
        container.removeFromSuperview()
        
        // Add to superview (window's content view's parent)
        superview.addSubview(container)
        
        // Position at top of superview to maintain accessibility
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: superview.topAnchor),
            container.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            container.heightAnchor.constraint(equalToConstant: 28) // Standard titlebar height
        ])
        
        // Make visible in fullscreen
        container.isHidden = false
        
        // Store original parent reference for restoration
        objc_setAssociatedObject(container, &Self.originalParentKey, originalParent, .OBJC_ASSOCIATION_RETAIN)
    }
    
    private func restoreContainerFromSuperview() {
        guard let container = titlebarContainerView,
              let originalParent = objc_getAssociatedObject(container, &Self.originalParentKey) as? NSView else { return }
        
        // Remove constraints
        container.removeFromSuperview()
        
        // Restore to original parent
        originalParent.addSubview(container)
        
        // Reset frame and hide
        container.translatesAutoresizingMaskIntoConstraints = true
        var frame = container.frame
        frame.size.height = 0
        container.frame = frame
        container.isHidden = true
        
        // Clean up stored reference
        objc_setAssociatedObject(container, &Self.originalParentKey, nil, .OBJC_ASSOCIATION_RETAIN)
    }

    // Main method that orchestrates everything
    func yeet() {
        disableTitlebar()
    }
}