#!/usr/bin/env python3
import sys
import os
import socket
import ssl
import urllib.parse
import html
import hashlib
import subprocess

def get_sandbox_dir():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    sdir = os.path.join(script_dir, "sandbox")
    os.makedirs(sdir, exist_ok=True)
    return sdir

def url_to_cache_path(url):
    h = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
    clean_name = url.replace("gemini://", "").replace("http://", "").replace("https://", "")
    clean_name = "".join(c if c.isalnum() or c in ".-_" else "_" for c in clean_name)
    if len(clean_name) > 30:
        clean_name = clean_name[:30]
    return os.path.join(get_sandbox_dir(), f"{clean_name}_{h}.gemini.html")

def lynx_executable():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(script_dir, "native", "lynx.exe"),
        os.path.join(script_dir, "native", "lynx"),
        os.path.join(script_dir, "lynx2.9.3", "lynx.exe"),
        os.path.join(script_dir, "lynx2.9.3", "lynx"),
        os.path.join(script_dir, "lynx2.9.3", "bin", "lynx.exe"),
        os.path.join(script_dir, "lynx2.9.3", "bin", "lynx"),
    ]
    for c in candidates:
        if os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    return "lynx"

def fetch_gemini_raw(url, max_redirects=5):
    for _ in range(max_redirects):
        parsed = urllib.parse.urlparse(url)
        if not parsed.scheme:
            url = "gemini://" + url
            parsed = urllib.parse.urlparse(url)

        host = parsed.hostname
        if not host:
            raise ValueError(f"Invalid host in Gemini URL: {url}")

        port = parsed.port or 1965
        path = parsed.path or "/"
        if parsed.query:
            path += "?" + parsed.query

        request_url = f"gemini://{host}{':' + str(port) if parsed.port else ''}{path}\r\n"

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        with socket.create_connection((host, port), timeout=10) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as ssock:
                ssock.sendall(request_url.encode("utf-8"))
                response = b""
                while True:
                    chunk = ssock.recv(4096)
                    if not chunk:
                        break
                    response += chunk

        if not response:
            raise ValueError("Empty response from Gemini server")

        header_end = response.find(b"\r\n")
        if header_end == -1:
            header_line = response.decode("utf-8", errors="replace").strip()
            body = b""
        else:
            header_line = response[:header_end].decode("utf-8", errors="replace").strip()
            body = response[header_end + 2:]

        parts = header_line.split(None, 1)
        status_str = parts[0] if parts else "20"
        meta = parts[1] if len(parts) > 1 else ""

        status_code = int(status_str) if status_str.isdigit() else 20

        if 30 <= status_code < 40:
            redirect_target = meta.strip()
            url = urllib.parse.urljoin(url, redirect_target)
            continue

        return status_code, meta, body, url

    raise ValueError("Too many redirects")

def gemtext_to_html(gemtext, base_url, title="Gemini Page"):
    lines = gemtext.splitlines()
    html_lines = [
        "<!DOCTYPE html>",
        "<html>",
        "<head>",
        '<meta charset="UTF-8">',
        f"<title>{html.escape(title)}</title>",
        "</head>",
        "<body>"
    ]

    in_pre = False
    in_list = False

    for line in lines:
        if line.startswith("```"):
            if in_list:
                html_lines.append("</ul>")
                in_list = False
            if in_pre:
                html_lines.append("</pre>")
                in_pre = False
            else:
                alt = html.escape(line[3:].strip())
                html_lines.append(f'<pre alt="{alt}">')
                in_pre = True
            continue

        if in_pre:
            html_lines.append(html.escape(line))
            continue

        stripped = line.strip()

        if stripped.startswith("* "):
            if not in_list:
                html_lines.append("<ul>")
                in_list = True
            item_text = html.escape(stripped[2:].strip())
            html_lines.append(f"<li>{item_text}</li>")
            continue
        elif in_list:
            html_lines.append("</ul>")
            in_list = False

        if stripped.startswith("=>"):
            parts = stripped[2:].strip().split(None, 1)
            if parts:
                target_url = parts[0]
                label = html.escape(parts[1]) if len(parts) > 1 else html.escape(target_url)
                resolved_url = urllib.parse.urljoin(base_url, target_url)
                html_lines.append(f'<p>=&gt; <a href="{html.escape(resolved_url)}">{label}</a></p>')
            continue

        if stripped.startswith("###"):
            html_lines.append(f"<h3>{html.escape(stripped[3:].strip())}</h3>")
        elif stripped.startswith("##"):
            html_lines.append(f"<h2>{html.escape(stripped[2:].strip())}</h2>")
        elif stripped.startswith("#"):
            html_lines.append(f"<h1>{html.escape(stripped[1:].strip())}</h1>")
        elif stripped.startswith(">"):
            html_lines.append(f"<blockquote>{html.escape(stripped[1:].strip())}</blockquote>")
        elif stripped == "":
            html_lines.append("<br>")
        else:
            html_lines.append(f"<p>{html.escape(stripped)}</p>")

    if in_list:
        html_lines.append("</ul>")
    if in_pre:
        html_lines.append("</pre>")

    html_lines.append("</body></html>")
    return "\n".join(html_lines)

def render_response_to_html(status_code, meta, body, final_url):
    if status_code == 10 or status_code == 11:
        prompt = html.escape(meta or "Input required")
        return f"""<!DOCTYPE html><html><head><title>Gemini Input Required</title></head><body>
<h2>Input Required</h2>
<p>{prompt}</p>
<p>To submit input, reload this URL with query parameter: <code>{html.escape(final_url)}?your_query</code></p>
</body></html>"""

    if 20 <= status_code < 30:
        meta_lower = meta.lower()
        if "text/html" in meta_lower:
            return body.decode("utf-8", errors="replace")
        elif "text/gemini" in meta_lower or meta_lower == "" or "text/" in meta_lower:
            gemtext = body.decode("utf-8", errors="replace")
            parsed_url = urllib.parse.urlparse(final_url)
            page_title = parsed_url.hostname or "Gemini Document"
            return gemtext_to_html(gemtext, final_url, title=page_title)
        else:
            content = body.decode("utf-8", errors="replace")
            return f"""<!DOCTYPE html><html><head><title>Gemini Document</title></head><body>
<pre>{html.escape(content)}</pre>
</body></html>"""

    return f"""<!DOCTYPE html><html><head><title>Gemini Error</title></head><body>
<h2>Gemini Status {status_code}</h2>
<p>{html.escape(meta or 'An error occurred while fetching Gemini URL.')}</p>
<p>URL: {html.escape(final_url)}</p>
</body></html>"""

def main():
    if len(sys.argv) < 2:
        print("Usage: gemini_fetcher.py <gemini_url> [output_file_path]")
        sys.exit(1)

    url = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        status_code, meta, body, final_url = fetch_gemini_raw(url)
        rendered_html = render_response_to_html(status_code, meta, body, final_url)
    except Exception as e:
        rendered_html = f"""<!DOCTYPE html><html><head><title>Gemini Error</title></head><body>
<h2>Error Fetching Gemini URL</h2>
<p>{html.escape(str(e))}</p>
<p>URL: {html.escape(url)}</p>
</body></html>"""

    if out_path:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(rendered_html)
    else:
        cache_file = url_to_cache_path(url)
        with open(cache_file, "w", encoding="utf-8") as f:
            f.write(rendered_html)

        if sys.stdout.isatty():
            lynx_bin = lynx_executable()
            cfg_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lynx.cfg")
            cmd = [lynx_bin]
            if os.path.exists(cfg_file):
                cmd.extend(["-cfg", cfg_file])
            cmd.append(cache_file)
            subprocess.run(cmd)
        else:
            print(rendered_html)

if __name__ == "__main__":
    main()
