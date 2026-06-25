#!/usr/bin/env python3
import sys
import urllib.request
import urllib.parse
import re
import json
from html.parser import HTMLParser

class DDGLiteParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.results = []
        self.current_result = None
        self.in_snippet = False
        self.snippet_data = []
        self.in_link = False
        self.link_text = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)

        if tag == 'a' and attrs_dict.get('class') == 'result-link':
            href = attrs_dict.get('href', '')
            url = href
            if 'uddg=' in href:
                parsed_url = urllib.parse.urlparse(href)
                query_params = urllib.parse.parse_qs(parsed_url.query)
                if 'uddg' in query_params:
                    url = query_params['uddg'][0]
            elif href.startswith('//'):
                url = 'https:' + href

            self.current_result = {'url': url, 'title': '', 'snippet': ''}
            self.in_link = True
            self.link_text = []

        elif tag == 'td' and attrs_dict.get('class') == 'result-snippet':
            self.in_snippet = True
            self.snippet_data = []

    def handle_endtag(self, tag):
        if tag == 'a' and self.in_link:
            self.in_link = False
            if self.current_result:
                self.current_result['title'] = ''.join(self.link_text).strip()
        elif tag == 'td' and self.in_snippet:
            self.in_snippet = False
            if self.current_result:
                self.current_result['snippet'] = ''.join(self.snippet_data).strip()
                self.current_result['snippet'] = re.sub(r'\s+', ' ', self.current_result['snippet'])
                self.results.append(self.current_result)
                self.current_result = None

    def handle_data(self, data):
        if self.in_link:
            self.link_text.append(data)
        elif self.in_snippet:
            self.snippet_data.append(data)

class YahooParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.results = []
        self.current_result = None
        self.in_title = False
        self.title_text = []
        self.in_snippet = False
        self.snippet_text = []

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        cls = attrs_dict.get('class', '')

        if tag == 'div' and 'compTitle' in cls and 'options-toggle' in cls:
            self.current_result = {'url': '', 'title': '', 'snippet': ''}
            self.in_title = True
            self.title_text = []
        elif tag == 'a' and self.in_title:
            href = attrs_dict.get('href', '')
            url = href
            if 'RU=' in href:
                ru_idx = href.find('RU=')
                if ru_idx != -1:
                    ru_part = href[ru_idx+3:]
                    rk_idx = ru_part.find('/')
                    if rk_idx != -1:
                        ru_part = ru_part[:rk_idx]
                    url = urllib.parse.unquote(ru_part)
            if self.current_result:
                self.current_result['url'] = url

        elif tag == 'div' and 'compText' in cls:
            self.in_snippet = True
            self.snippet_text = []

    def handle_endtag(self, tag):
        if tag == 'a' and self.in_title:
            self.in_title = False
            if self.current_result:
                raw_title = ''.join(self.title_text).strip()

                if '›' in raw_title:
                    raw_title = raw_title.split('›')[-1].strip()
                self.current_result['title'] = raw_title
        elif tag == 'div' and self.in_snippet:
            self.in_snippet = False
            if self.current_result:
                self.current_result['snippet'] = ''.join(self.snippet_text).strip()
                self.current_result['snippet'] = re.sub(r'\s+', ' ', self.current_result['snippet'])
                if self.current_result['url'] and self.current_result['title']:
                    self.results.append(self.current_result)
                self.current_result = None

    def handle_data(self, data):
        if self.in_title:
            self.title_text.append(data)
        elif self.in_snippet:
            self.snippet_text.append(data)

def search_ddg(query):
    url = 'https://lite.duckduckgo.com/lite/?q=' + urllib.parse.quote(query)
    headers = {
        'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5'
    }

    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            html_content = response.read().decode('utf-8', errors='ignore')

            if "anomaly-modal" in html_content or "Select all squares containing a duck" in html_content:
                print("DuckDuckGo Lite returned a CAPTCHA challenge.", file=sys.stderr)
                return []
            parser = DDGLiteParser()
            parser.feed(html_content)
            return parser.results
    except Exception as e:
        print(f"Error executing DuckDuckGo Lite search: {e}", file=sys.stderr)
        return []

def search_yahoo(query):
    url = 'https://search.yahoo.com/search?p=' + urllib.parse.quote(query)
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5'
    }

    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            html_content = response.read().decode('utf-8', errors='ignore')
            parser = YahooParser()
            parser.feed(html_content)
            return parser.results
    except Exception as e:
        print(f"Error executing Yahoo search: {e}", file=sys.stderr)
        return []

def search_wikipedia(query):
    try:
        url = 'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=' + urllib.parse.quote(query) + '&format=json'
        req = urllib.request.Request(url, headers={'User-Agent': 'CaelestiaAgent/1.0'})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))
            results = []
            for item in data.get('query', {}).get('search', []):
                title = item.get('title', '')
                snippet = item.get('snippet', '')
                snippet = re.sub(r'<[^>]*>', '', snippet)
                pageid = item.get('pageid', '')
                url = f"https://en.wikipedia.org/?curid={pageid}"
                results.append({'url': url, 'title': title, 'snippet': snippet})
            return results
    except Exception as e:
        print(f"Error executing Wikipedia search: {e}", file=sys.stderr)
        return []

def main():
    if len(sys.argv) < 2:
        print("Usage: web_search.py <query>")
        sys.exit(1)

    query = ' '.join(sys.argv[1:])
    print(f"Searching for: \"{query}\"...", file=sys.stderr)

    results = search_ddg(query)

    if not results:
        print("DuckDuckGo Lite returned no results. Trying Yahoo Search fallback...", file=sys.stderr)
        results = search_yahoo(query)

    if not results:
        print("Yahoo Search returned no results. Trying Wikipedia Search fallback...", file=sys.stderr)
        results = search_wikipedia(query)

    if not results:
        print("No search results found or an error occurred.")
        return

    for i, res in enumerate(results[:5], 1):
        print(f"[{i}] Title: {res['title']}")
        print(f"    URL: {res['url']}")
        print(f"    Snippet: {res['snippet']}\n")

if __name__ == '__main__':
    main()
