import Foundation
import WebKit

public enum WebPerformanceSignal {
    case request(WebSendAttempt)
    case status(WebSendAttempt)
    case cancellationRequested(WebSendAttempt)
    case canceled(WebSendAttempt)
    case snapshot(comparisonID: UUID, documentID: String, snapshot: WebPageSnapshot)
    case gap(comparisonID: UUID, reason: String)
}

/// Notifies native code of conversation mutations only. Extracted content still
/// goes through the existing provider adapter and page-generation ownership checks.
@MainActor
final class WebPerformanceObserver: NSObject, WKScriptMessageHandler {
    weak var session: WebAgentSession?
    init(session: WebAgentSession) { self.session = session }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "msgblastPerformance", let view = message.webView,
              let body = message.body as? [String: String], body["signal"] == "conversation-changed" else { return }
        session?.performanceMutation(in: view)
    }
    static let install = #"""
    if (!globalThis.__msgblastPerformanceObserver) {
      const root = document.querySelector('[aria-label="Chat messages"],#hatch-chat-scroll,[data-testid="conversation-turns"],main');
      if (root) {
        let pending;
        const notify = () => { clearTimeout(pending); pending=setTimeout(()=>window.webkit.messageHandlers.msgblastPerformance.postMessage({signal:'conversation-changed'}),100); };
        const observer = new MutationObserver(notify);
        observer.observe(root,{subtree:true,childList:true,characterData:true});
        globalThis.__msgblastPerformanceObserver={observer,stop:()=>{observer.disconnect();clearTimeout(pending);}};
      }
    }
    """#
    static let remove = "globalThis.__msgblastPerformanceObserver?.stop(); delete globalThis.__msgblastPerformanceObserver;"
}
