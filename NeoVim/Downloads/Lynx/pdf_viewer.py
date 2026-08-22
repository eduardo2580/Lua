#!/usr/bin/env python3
import sys
import html
import os
from pypdf import PdfReader

def main():
    if len(sys.argv) < 2:
        print("<html><body><h3>Error: No PDF file specified</h3></body></html>")
        sys.exit(1)

    pdf_path = sys.argv[1]
    if not os.path.exists(pdf_path):
        print(f"<html><body><h3>Error: File not found: {html.escape(pdf_path)}</h3></body></html>")
        sys.exit(1)

    try:
        reader = PdfReader(pdf_path)
        num_pages = len(reader.pages)
        title = os.path.basename(pdf_path)

        html_out = [
            "<!DOCTYPE html>",
            "<html>",
            "<head>",
            f"<title>{html.escape(title)}</title>",
            "<style>",
            "body { font-family: monospace; line-height: 1.4; padding: 1em; }",
            ".page-header { background: #333; color: #fff; padding: 4px 8px; margin-top: 1em; font-weight: bold; }",
            "pre { white-space: pre-wrap; word-wrap: break-word; }",
            "</style>",
            "</head>",
            "body>",
            f"<h2>PDF Document Viewer: {html.escape(title)}</h2>",
            f"<p>Total Pages: {num_pages}</p>",
            "<hr/>"
        ]

        for i, page in enumerate(reader.pages):
            page_text = page.extract_text() or "[No readable text on this page]"
            html_out.append(f"<div class='page-header'>--- Page {i + 1} of {num_pages} ---</div>")
            html_out.append(f"<pre>{html.escape(page_text)}</pre>")

        html_out.append("</body></html>")
        print("\n".join(html_out))
    except Exception as e:
        print(f"<html><body><h3>Error reading PDF: {html.escape(str(e))}</h3></body></html>")

if __name__ == "__main__":
    main()
