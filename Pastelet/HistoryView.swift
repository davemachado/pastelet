import SwiftUI

struct HistoryView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @State private var selectedIndex: Int = 0
    var onSelect: (ClipboardItem) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar (Visual only for now, or functional?)
            // Let's keep it minimal: Just the list.
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(clipboardManager.history.enumerated()), id: \.element.id) { index, item in
                            HistoryRow(item: item, isSelected: index == selectedIndex)
                                .id(index)
                                .onTapGesture {
                                    onSelect(item)
                                }
                        }
                    }
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        // Keyboard Handling
        .background(
            KeyHandler(selectedIndex: $selectedIndex, maxIndex: clipboardManager.history.count, onEnter: {
                if clipboardManager.history.indices.contains(selectedIndex) {
                    onSelect(clipboardManager.history[selectedIndex])
                }
            }, onEscape: onCancel)
        )
        .frame(width: 350, height: 400)
    }
}

struct HistoryRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text(item.content)
                .lineLimit(1)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : .primary)
            
            Spacer()
            
            Text(item.date, style: .time)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue : Color.clear)
        .contentShape(Rectangle())
    }
}

// Helper for Visual Effect (Glass)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Hidden View to handle keyboard events via NSView
struct KeyHandler: NSViewRepresentable {
    @Binding var selectedIndex: Int
    let maxIndex: Int
    let onEnter: () -> Void
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> KeyListeningView {
        let view = KeyListeningView()
        view.onKeyDown = { code in
            switch code {
            case 125: // Down Arrow
                if selectedIndex < maxIndex - 1 {
                    selectedIndex += 1
                }
            case 126: // Up Arrow
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
            case 36: // Enter
                onEnter()
            case 53: // Escape
                onEscape()
            default:
                break
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: KeyListeningView, context: Context) {
        nsView.maxIndex = maxIndex
    }
}

class KeyListeningView: NSView {
    var onKeyDown: ((UInt16) -> Void)?
    var maxIndex: Int = 0
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        onKeyDown?(event.keyCode)
    }
    
    // We need to ensure we become first responder when added
    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }
}
