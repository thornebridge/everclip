import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = MarkdownRenderer.render(markdown)
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Simple Markdown → HTML renderer (common subset)

enum MarkdownRenderer {
    static func render(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var html: [String] = []
        var inCodeBlock = false
        var codeBlockContent: [String] = []
        var inList = false
        var listTag = "ul"

        for line in lines {
            // Code fences
            if line.hasPrefix("```") {
                if inCodeBlock {
                    html.append("<pre><code>\(codeBlockContent.joined(separator: "\n").escaped)</code></pre>")
                    codeBlockContent.removeAll()
                    inCodeBlock = false
                } else {
                    closeList(&html, &inList, &listTag)
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                codeBlockContent.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Headings
            if let heading = parseHeading(trimmed) {
                closeList(&html, &inList, &listTag)
                html.append(heading)
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                closeList(&html, &inList, &listTag)
                html.append("<hr/>")
                continue
            }

            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !inList { html.append("<ul>"); inList = true; listTag = "ul" }
                let content = String(trimmed.dropFirst(2))
                html.append("<li>\(inlineFormat(content))</li>")
                continue
            }

            // Ordered list
            if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                if !inList { html.append("<ol>"); inList = true; listTag = "ol" }
                let content = String(trimmed[match.upperBound...])
                html.append("<li>\(inlineFormat(content))</li>")
                continue
            }

            closeList(&html, &inList, &listTag)

            if trimmed.isEmpty {
                html.append("<br/>")
            } else {
                html.append("<p>\(inlineFormat(trimmed))</p>")
            }
        }

        closeList(&html, &inList, &listTag)
        if inCodeBlock {
            html.append("<pre><code>\(codeBlockContent.joined(separator: "\n").escaped)</code></pre>")
        }

        return wrapHTML(html.joined(separator: "\n"))
    }

    private static func closeList(_ html: inout [String], _ inList: inout Bool, _ listTag: inout String) {
        if inList { html.append("</\(listTag)>"); inList = false; listTag = "ul" }
    }

    private static func parseHeading(_ line: String) -> String? {
        let levels = [(6, "######"), (5, "#####"), (4, "####"), (3, "###"), (2, "##"), (1, "#")]
        for (level, prefix) in levels {
            if line.hasPrefix(prefix + " ") {
                let content = String(line.dropFirst(prefix.count + 1))
                return "<h\(level)>\(inlineFormat(content))</h\(level)>"
            }
        }
        return nil
    }

    private static func inlineFormat(_ text: String) -> String {
        var result = text.escaped
        // Bold
        result = result.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"__(.+?)__"#, with: "<strong>$1</strong>", options: .regularExpression)
        // Italic
        result = result.replacingOccurrences(of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_(.+?)_"#, with: "<em>$1</em>", options: .regularExpression)
        // Inline code
        result = result.replacingOccurrences(of: #"`(.+?)`"#, with: "<code>$1</code>", options: .regularExpression)
        // Links
        result = result.replacingOccurrences(of: #"\[(.+?)\]\((.+?)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        return result
    }

    private static func wrapHTML(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8">
        <style>
            body {
                font-family: -apple-system, sans-serif; font-size: 11px;
                color: #e0e0e0; background: transparent;
                margin: 0; padding: 4px;
                -webkit-font-smoothing: antialiased;
            }
            h1,h2,h3,h4,h5,h6 { margin: 4px 0 2px; font-weight: 600; }
            h1 { font-size: 15px; } h2 { font-size: 13px; } h3 { font-size: 12px; }
            pre { background: rgba(0,0,0,0.2); padding: 4px 6px; border-radius: 4px; overflow-x: auto; }
            code { font-family: Menlo, monospace; font-size: 10px; background: rgba(0,0,0,0.15); padding: 1px 3px; border-radius: 2px; }
            pre code { background: none; padding: 0; }
            a { color: #60A5FA; }
            hr { border: none; border-top: 1px solid rgba(255,255,255,0.1); margin: 6px 0; }
            p { margin: 2px 0; }
            ul, ol { margin: 2px 0; padding-left: 16px; }
            li { margin: 1px 0; }
            @media (prefers-color-scheme: light) {
                body { color: #1a1a1a; }
                pre { background: rgba(0,0,0,0.05); }
                code { background: rgba(0,0,0,0.05); }
                a { color: #2563EB; }
                hr { border-top-color: rgba(0,0,0,0.1); }
            }
        </style></head>
        <body>\(body)</body></html>
        """
    }
}

private extension String {
    var escaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
