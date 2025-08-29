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
        let typeName = String(describing: type(of: self))
        
        NSLog("[Yeetbar] Layout called for view: %@ (window: %@)", typeName, window?.description ?? "nil")
        
        // More aggressive titlebar detection
        if typeName.contains("NSTitlebar") || 
           typeName.contains("Titlebar") ||
           typeName.contains("WindowHeader") ||
           typeName.contains("TopBar") ||
           typeName.contains("HeaderView") ||
           typeName.contains("ThemeFrame") ||
           typeName.contains("NSThemeFrame") ||
           window?.isLikelyTitlebar(self) == true {
            NSLog("[Yeetbar] Layout triggered yeet for: %@", typeName)
            window?.yeet()
        }
        
        // Force yeet on any window that gets laid out
        if let window = window {
            NSLog("[Yeetbar] Force yeeting window: %@", window)
            window.yeet()
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
        NSLog("[Yeetbar] disableTitlebar() called on window: %@", self)
        
        // Skip titlebar modification during fullscreen transitions to prevent crashes
        guard !isInFullscreenTransition() else {
            NSLog("[Yeetbar] Skipping - in fullscreen transition")
            // Schedule retry after transition completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.yeet()
            }
            return
        }
        
        // Additional safety check - don't modify if window is not ready
        guard contentView != nil else {
            NSLog("[Yeetbar] Skipping - no content view")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.yeet()
            }
            return
        }
        
        NSLog("[Yeetbar] Disabling titlebar for window: %@", self)
        
        // Special handling for SwiftUI windows
        let windowClassName = String(describing: type(of: self))
        if windowClassName.contains("SwiftUI") {
            NSLog("[Yeetbar] Detected SwiftUI window, using aggressive approach")
            handleSwiftUIWindow()
        } else {
            NSLog("[Yeetbar] Using standard NSWindow approach")
            handleStandardWindow()
        }
        
        // More aggressive approach - hide ALL top-level views that look like titlebars
        hideAllPotentialTitlebars()
        
        // Safely hide titlebar without removing essential views
        hideTitlebarSafely()
        
        // Add fullscreen state monitoring for crash prevention
        setupFullscreenMonitoring()
    }
    
    private func handleSwiftUIWindow() {
        NSLog("[Yeetbar] Handling SwiftUI window")
        
        // Set standard properties
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        styleMask.insert(.fullSizeContentView)
        isMovableByWindowBackground = true
        
        // Hide traffic lights
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        NSLog("[Yeetbar] SwiftUI window properties set successfully")
        
        // Force hide all views that might be titlebars
        forceHideSwiftUITitlebars()
    }
    
    private func handleStandardWindow() {
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        styleMask.insert(.fullSizeContentView)
        isMovableByWindowBackground = true
        
        // Hide traffic lights
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    private func forceHideSwiftUITitlebars() {
        NSLog("[Yeetbar] Force hiding SwiftUI titlebars with refined detection")
        
        // Get all subviews of the window
        let allViews = getAllWindowSubviews()
        
        for view in allViews {
            let className = String(describing: type(of: view))
            let frame = view.frame
            
            // More precise detection - only target actual titlebar elements
            if frame.height > 0 && frame.height < 50 && frame.width > 300 {
                // Must be at the very top of the window (within 50 points of top)
                let windowHeight = view.window?.frame.height ?? 0
                let isAtVeryTop = frame.maxY >= windowHeight - 50
                
                // Only hide if it's specifically a titlebar-related class AND at the top
                let isTitlebarClass = className.lowercased().contains("title") || 
                                    className.lowercased().contains("header") ||
                                    (className.lowercased().contains("bar") && 
                                     !className.lowercased().contains("toolbar") &&
                                     !className.lowercased().contains("statusbar") &&
                                     !className.lowercased().contains("tabbar"))
                
                if isAtVeryTop && isTitlebarClass {
                    NSLog("[Yeetbar] Refined hiding SwiftUI titlebar: %@ (frame: %@)", className, NSStringFromRect(frame))
                    view.isHidden = true
                    view.alphaValue = 0.0
                    var newFrame = frame
                    newFrame.size.height = 0
                    view.frame = newFrame
                }
            }
        }
    }
    
    private func getAllWindowSubviews() -> [NSView] {
        var allViews: [NSView] = []
        
        func collectViews(_ v: NSView) {
            allViews.append(v)
            for subview in v.subviews {
                collectViews(subview)
            }
        }
        
        if let contentView = contentView {
            collectViews(contentView)
        }
        
        // Also check direct window subviews
        for subview in self.contentView?.superview?.subviews ?? [] {
            collectViews(subview)
        }
        
        return allViews
    }
    
    private func hideTitlebarSafely() {
        guard let contentView = contentView else { return }
        
        // Only hide titlebar views without relocating to prevent crashes
        hideTitlebarViews(in: contentView)
        
        // Use window properties to minimize titlebar space
        minimizeTitlebarSpace()
    }
    
    func isLikelyTitlebar(_ view: NSView) -> Bool {
        guard let _ = view.window else { return false }
        
        let frame = view.frame
        
        // Check if view is at the top of the window
        let isAtTop = frame.maxY >= (view.superview?.frame.height ?? 0) - 50
        
        // Check if view spans most of the window width
        let spansWidth = frame.width > (view.superview?.frame.width ?? 0) * 0.7
        
        // Check if view has titlebar-like height (typically 22-44 points)
        let hasTitlebarHeight = frame.height >= 20 && frame.height <= 50
        
        return isAtTop && spansWidth && hasTitlebarHeight
    }
    
    private func hideAllPotentialTitlebars() {
        guard let contentView = contentView else { return }
        
        // Search through all window views aggressively
        searchAndHideTitlebars(in: contentView)
        
        // Also check the window's direct subviews
        for subview in self.contentView?.superview?.subviews ?? [] {
            searchAndHideTitlebars(in: subview)
        }
        
        // Force hide any view with "title" or "header" in its class name
        hideViewsByClassName(in: contentView)
    }
    
    private func searchAndHideTitlebars(in view: NSView) {
        let typeName = String(describing: type(of: view))
        
        // More precise detection - only hide actual titlebar elements
        if view.frame.height > 0 && view.frame.height < 50 && 
           view.frame.width > 300 {
            
            // Must be at the very top of the window
            let windowHeight = view.window?.frame.height ?? 0
            let isAtVeryTop = view.frame.maxY >= windowHeight - 50
            
            // Only hide if it's specifically a titlebar class AND at the top
            let isTitlebarClass = typeName.lowercased().contains("title") ||
                                typeName.lowercased().contains("header") ||
                                (typeName.lowercased().contains("bar") && 
                                 !typeName.lowercased().contains("toolbar") &&
                                 !typeName.lowercased().contains("statusbar") &&
                                 !typeName.lowercased().contains("tabbar"))
            
            if isAtVeryTop && isTitlebarClass {
                NSLog("[Yeetbar] Refined hiding titlebar: %@ (frame: %@)", typeName, NSStringFromRect(view.frame))
                view.isHidden = true
                var frame = view.frame
                frame.size.height = 0
                view.frame = frame
            }
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            searchAndHideTitlebars(in: subview)
        }
    }
    
    private func hideViewsByClassName(in view: NSView) {
        for subview in view.subviews {
            let typeName = String(describing: type(of: subview))
            let frame = subview.frame
            
            // Only hide if it's at the top AND has titlebar-like characteristics
            let windowHeight = subview.window?.frame.height ?? 0
            let isAtVeryTop = frame.maxY >= windowHeight - 50
            let hasTitlebarSize = frame.height > 0 && frame.height < 50 && frame.width > 300
            
            if isAtVeryTop && hasTitlebarSize && (
               typeName.lowercased().contains("title") ||
               typeName.lowercased().contains("header") ||
               (typeName.lowercased().contains("bar") && 
                !typeName.lowercased().contains("toolbar") &&
                !typeName.lowercased().contains("statusbar") &&
                !typeName.lowercased().contains("tabbar"))) {
                NSLog("[Yeetbar] Refined hiding view by class name: %@", typeName)
                subview.isHidden = true
            }
            
            hideViewsByClassName(in: subview)
        }
    }
    
    private func hideVisualTitlebarElementsInContainer(_ container: NSView) {
        NSLog("[Yeetbar] Selectively hiding visual elements in titlebar container")
        
        for subview in container.subviews {
            let typeName = String(describing: type(of: subview))
            
            // Only hide visual background/decoration elements, preserve functional tools
            let isVisualElement = typeName.contains("Background") ||
                                typeName.contains("Decoration") ||
                                typeName.contains("Shadow") ||
                                typeName.contains("Border") ||
                                (typeName.contains("NSView") && subview.subviews.isEmpty) ||
                                typeName.contains("_NSTitlebarDecorationView")
            
            if isVisualElement {
                NSLog("[Yeetbar] Hiding visual titlebar element: %@", typeName)
                subview.isHidden = true
                subview.alphaValue = 0.0
            } else {
                NSLog("[Yeetbar] Preserving functional titlebar element: %@", typeName)
                // Recursively process functional elements but don't hide them
                hideVisualTitlebarElementsInContainer(subview)
            }
        }
    }
    
    private func hideTitlebarViews(in view: NSView) {
        for subview in view.subviews {
            let typeName = String(describing: type(of: subview))
            
            // Debug logging to identify titlebar class names
            if typeName.lowercased().contains("title") || 
               typeName.lowercased().contains("header") ||
               typeName.lowercased().contains("bar") {
                NSLog("[Yeetbar] Found potential titlebar view: %@", typeName)
            }
            
            // Expanded detection for various titlebar implementations
            let isTitlebarView = typeName.contains("NSTitlebarView") ||
                               typeName.contains("TitlebarView") ||
                               typeName.contains("WindowHeaderView") ||
                               typeName.contains("TopBarView") ||
                               typeName.contains("HeaderBarView") ||
                               typeName.contains("_NSTitlebarView") ||
                               typeName.contains("NSThemeFrame") ||
                               typeName.contains("ThemeFrame") ||
                               (typeName.contains("NSView") && isLikelyTitlebar(subview))
            
            let isTitlebarContainer = typeName.contains("NSTitlebarContainerView") ||
                                    typeName.contains("TitlebarContainerView") ||
                                    typeName.contains("WindowHeaderContainerView") ||
                                    typeName.contains("TopBarContainerView") ||
                                    typeName.contains("HeaderContainerView") ||
                                    typeName.contains("_NSTitlebarContainerView")
            
            if isTitlebarView {
                NSLog("[Yeetbar] Hiding titlebar view: %@", typeName)
                // Hide the titlebar but don't remove it
                subview.isHidden = true
                
                // Try to minimize its frame height
                var frame = subview.frame
                frame.size.height = 0
                subview.frame = frame
            } else if isTitlebarContainer {
                NSLog("[Yeetbar] Preserving titlebar container functionality: %@", typeName)
                // Store reference to titlebar container for fullscreen handling
                titlebarContainerView = subview
                
                // PRESERVE the container - don't hide it or change its frame
                // Instead, hide only the visual titlebar elements inside it
                hideVisualTitlebarElementsInContainer(subview)
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
        // For SwiftUI windows, be less restrictive - check this first
        let windowClassName = String(describing: type(of: self))
        NSLog("[Yeetbar] Window class name: %@", windowClassName)
        if windowClassName.contains("AppKitWindow") {
            NSLog("[Yeetbar] SwiftUI AppKitWindow detected, skipping fullscreen transition checks")
            return false
        }
        
        // Check if window is currently transitioning to/from fullscreen
        if styleMask.contains(.fullScreen) {
            NSLog("[Yeetbar] Window is in fullscreen, safe to modify")
            return false // Already in fullscreen, safe to modify
        }
        
        // Check for transition states that could cause crashes
        let isTransitioning = (styleMask.rawValue & 0x4000) != 0 // NSWindowStyleMaskFullScreenWindow
        
        // Additional safety checks
        let hasFullScreenAuxiliary = (styleMask.rawValue & 0x8000) != 0
        let isAnimating = responds(to: Selector(("isInFullScreenTransition"))) && 
                         perform(Selector(("isInFullScreenTransition"))).takeUnretainedValue().boolValue
        
        NSLog("[Yeetbar] Fullscreen transition check - isTransitioning: %@, hasFullScreenAuxiliary: %@, isAnimating: %@, styleMask: %lu", 
              isTransitioning ? "YES" : "NO", 
              hasFullScreenAuxiliary ? "YES" : "NO", 
              isAnimating ? "YES" : "NO", 
              styleMask.rawValue)
        
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
        NSLog("[Yeetbar] yeet() called on window: %@", self)
        
        // Skip system windows to preserve menubar and UI functionality
        let windowClassName = String(describing: type(of: self))
        if windowClassName.contains("MenuBar") || 
           windowClassName.contains("StatusBar") ||
           windowClassName.contains("Dock") ||
           windowClassName.contains("PopupMenu") ||
           windowClassName.contains("ContextMenu") ||
           windowClassName.contains("TUINSWindow") {
            NSLog("[Yeetbar] Skipping system window: %@", windowClassName)
            return
        }
        
        disableTitlebar()
    }
}