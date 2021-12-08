# gawk script to see if a URL is blocked by Privoxy or not
# requires the |& gawk extension for coprocessing to do
#   webserver = "/inet/tcp/0/localhost/8118"
# and my changes to Privoxy adding the show-url-final-info cgi function
#   print "GET http://config.privoxy.org/show-url-final-info?url=" url " HTTP/1.1"  |& webserver
#   while ( (webserver |& getline) > 0 ) {
# that is so much faster than
#   cmd = "curl -q --proxy 127.0.0.1:8118 --silent http://p.p/show-url-info?url=http://" url
#   while ( ( cmd | getline ) > 0 ) {
# ref: https://www.gnu.org/software/gawk/manual/gawkinet/gawkinet.html

BEGIN {
  prev = "@";  prevlen = 1;
  stderr = "/dev/stderr"
  webserver = "/inet/tcp/0/localhost/8118"
  # awk -v debug=1 ...  to enable debug output
  # awk -v nocheckprev=1 to not check if the previous url matches this url
  #    eg:  .example.org
  #         www.example.org
  #    do you want www.example.org to show up as "blocked by prev" or no?
}

            { sub("\r", "", $0) }  # fix any \r\n line endings
/^[ \t]*#/  { print $0; next }  # echo comment lines to output
/^[ \t]*{/  { print $0; next }  # echo ??WTF are these called?? lines to output
/^ *$/      { print $0; next }  # echo blank lines to output

{
  sub("^[ \t]+", "", $0)  # remove leading whitespace
  sub("#.*$", "", $0)     # remove inline comment
  sub("[ \t]+$", "", $0)  # remove trailing whitespace
  url = $0

  if ( url !~ /^[-_~a-zA-Z0-9%\.\/]*$/ ) {
     # allowed characters in a URL pattern are
     #   dash(-), underscore(_), tilde(~), letter, digit, percent(%), period(.), slash(/)
     printf("# invalid URL: %s\n", url)
     next
  }
  if ( url ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ ) {
     printf("# *************************** skipping IP address: %s\n", url)
     next
  }
  if ( url ~ /^localhost\.?$/ ) {
     printf("# *************************** skipping localhost: %s\n", url)
     next
  }

  checkurl = url
  if ( substr(url, 1, 1) == "." ) { checkurl = "foo" url }   # tack a name on the front if the pattern has a leading dot
  if ( substr(checkurl, length(checkurl), 1) == "." )
     checkurl = checkurl "co.uk/"  # tack a domain on the end if pattern has trailing dot
  blocked = privoxyUrlInfo(checkurl)
       if ( blocked == "+" ) printf("# already blocked: %s\n", url)
  else if ( blocked != "-" ) {
     printf("############################# unknown:%s: %s\n", blocked, url)
  } else { # not already blocked
     n = length(url)
     if ( (nocheckprev == 0) && ( n >= prevlen ) && ( substr(url, (n-prevlen)+1) == prev) ) {
        printf("# blocked by prev: %s\n", url)
     } else {
          # not blocked, add a leading "." unless it's an ip address or starts with "www."
        n=index(url, "/")
        if ( n > 0 ) host = substr(url, 1, n-1)
        else         host = url
        n = split(host, a, ".")
        if ( a[1] == "www" || ( (n == 4) && (host ~ "^[0-9.]*$") ) ) {
           # no leading "." for a.d.d.r or www.whatever urls
        } else if ( substr(url, 1, 1) != "." ) {
           url = "." url
        }
        printf("%s\n", url);
        prev = url; prevlen = length(prev);
     }
  }
} # end
END { privoxyUrlInfo("-_-_close_-_-")  # close webserver connection
}


function privoxyUrlInfo(url,   blocked, final, savedORS, done, status) {
#  return "+" : privoxy will block the url
#         "-" : privoxy will not block the url
#         " " : wtf went wrong???
  blocked = " "
  if ( url == "-_-_close_-_-" ) { close(webserver); return blocked }

  done = 0
  final = 0

  savedORS = ORS;  ORS="\r\n"  # lines sent to the webserver need \r\n line endings

# print "GET http://config.privoxy.org/show-url-info?url=" url " HTTP/1.1"  |& webserver
#   standard but slow - template is read from disk and calls merge_current_action
  print "GET http://config.privoxy.org/show-url-final-info?url=" url " HTTP/1.1"  |& webserver
#   nonstandard but fast - no disk reads and calls merge_single_actions
  print "Host: config.privoxy.org"                |& webserver
  print "Accept: text/html"                       |& webserver
  print "Connection: Keep-Alive"                  |& webserver
  print ""                                        |& webserver
  ORS = savedORS

  while ( ( ! done ) && ((status = (webserver |& getline)) > 0) ) {
     if ( ! final ) {
        if ( $0 ~ /Final results:/ ) final = 1
     } else {
        if ( $0 ~ /actions-file.html#BLOCK/ ) {
           blocked = substr($0, 5, 1) # either + or -
              # drain input
           while ( ( ! done ) && ((status = (webserver |& getline)) > 0) ) {
              if ( $0 ~ /<\/html>/ ) { done = 1 }
           }
        }
     }
     if ( $0 ~ /<\/html>/ ) {
        done = 1
     }
  }
  if ( status < 0 ) {
     close(webserver)
     printf(" * * * OhNoes!!!  webserver status = %s  done=%s\n", status, done)
  }
  return blocked
}
