# This should be usable as long as this service continues to be
# available.
INSERT INTO bpn_sources (name, active, source, regex, al2name) VALUES ('torharvard', 'yes', 'http://serifos.eecs.harvard.edu:8000/cgi-bin/exit.pl', '<a class="(?:unverified|standard)" href="/cgi-bin/whois\\.pl\\?q=(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3})">', 'nopostanon');

# If the above service becomes unavailable, this works too, but it is
# off by default since the above is easier.  Give the location of the
# cached-directory file on your system (the default location is where
# Debian installs it: 'apt-get install tor'), and set its permissions
# to be readable by your Slash unix user, maybe by adding that user
# to group debian-tor.  And if you turn this on, you can turn the
# above source off.
INSERT INTO bpn_sources (name, active, source, regex, al2name) VALUES ('torlocal', 'no', '/var/lib/tor/cached-directory', '(?m)^router \\s*\\S+\\s+(\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3})', 'nopostanon');

# You may want to create a new user for this, for convenient logging.
INSERT INTO vars (name, value, description) VALUES ('bpn_adminuid', '', 'Admin uid for BlockProxyNet plugin access modifiers');

