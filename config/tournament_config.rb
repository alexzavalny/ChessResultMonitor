# Tournament Configuration
TOURNAMENT_URL = 'https://s3.chess-results.com/tnr1246747.aspx?lan=1&art=9&fed=LAT&turdet=YES&flag=30&snr=61&SNode=S0'
MONITORING_INTERVAL = 15 # seconds
REQUEST_TIMEOUT = 30 # seconds
MAX_RETRIES = 3

# HTTP headers to mimic a real browser
HTTP_HEADERS = {
  'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
  'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Accept-Language' => 'en-US,en;q=0.5',
  'Accept-Encoding' => 'gzip, deflate',
  'Connection' => 'keep-alive'
}
