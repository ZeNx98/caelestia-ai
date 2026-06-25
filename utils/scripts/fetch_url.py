#!/usr/bin/env python3
import sys
import urllib.request
import urllib.parse
import re
from html.parser import HTMLParser

class HTMLTextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text_parts = []

        self.ignore_tags = {'script', 'style', 'head', 'nav', 'footer', 'noscript', 'aside', 'header', 'form', 'iframe', 'svg', 'button'}
        self.ignore_stack = []

    def handle_starttag(self, tag, attrs):
        if tag in self.ignore_tags:
            self.ignore_stack.append(tag)
            return

        if tag in {'h1', 'h2', 'h3'}:
            self.text_parts.append('\n\n### ')
        elif tag in {'h4', 'h5', 'h6'}:
            self.text_parts.append('\n\n#### ')
        elif tag == 'p':
            self.text_parts.append('\n\n')
        elif tag == 'br':
            self.text_parts.append('\n')
        elif tag in {'li', 'tr'}:
            self.text_parts.append('\n- ')
        elif tag in {'td', 'th'}:
            self.text_parts.append(' | ')

    def handle_endtag(self, tag):
        if self.ignore_stack and self.ignore_stack[-1] == tag:
            self.ignore_stack.pop()

    def handle_data(self, data):
        if not self.ignore_stack:
            self.text_parts.append(data)

    def get_text(self):
        full_text = ''.join(self.text_parts)

        full_text = re.sub(r'[ \t]+', ' ', full_text)

        full_text = re.sub(r'\n\s*\n+', '\n\n', full_text)
        return full_text.strip()

def fetch_url(url):

    if not url.startswith('http://') and not url.startswith('https://'):
        url = 'https://' + url

    headers = {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5'
    }

    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            content_type = response.headers.get('Content-Type', '')
            charset = 'utf-8'
            if 'charset=' in content_type:
                charset = content_type.split('charset=')[-1].strip()

            raw_data = response.read()

            if 'text/html' in content_type:
                html_content = raw_data.decode(charset, errors='ignore')
                parser = HTMLTextExtractor()
                parser.feed(html_content)
                text = parser.get_text()
                return text
            else:
                return raw_data.decode(charset, errors='ignore')
    except Exception as e:
        return f"Error fetching URL {url}: {e}"

def main():
    if len(sys.argv) < 2:
        print("Usage: fetch_url.py <url>")
        sys.exit(1)

    url = sys.argv[1]
    text = fetch_url(url)

    if len(text) > 6000:
        print(text[:6000])
        print("\n... (truncated due to length limit) ...")
    else:
        print(text)

if __name__ == '__main__':
    main()
