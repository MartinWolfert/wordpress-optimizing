# Varnish Config for WordPress
# Martin Wolfert - 2015/05/15
# http://blog.lichttraeumer.de
# Version 1.0

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

acl Purge {
        # For now, I'll only allow purges coming from localhost
        "127.0.0.1";
        "localhost";
        "91.250.113.206";
}


sub vcl_recv {

    # Set standard proxied ip header for getting original remote address
	# IP forwarding.
	if (req.restarts == 0) {
		if (req.http.x-forwarded-for) {
			set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
		} else {
			set req.http.X-Forwarded-For = client.ip;
		}
	}

	# Namespace normalizing
	if (req.http.host ~ "(?i)^(c|j)?-blog.lichttraeumer.de") {
  		set req.http.host = "blog.lichttraeumer.de";
	}

        # Handling purge requests, also for varnisher
        if (req.method == "PURGE") {
                if (!client.ip ~ Purge) {
                        return(synth(405,"Not allowed."));
                }
                return (purge);
        }
        if (req.method == "DOMAINPURGE") {
                if (!client.ip ~ Purge) {
                        return(synth(405,"Not allowed."));
                }
                return (purge);
        }

	# Do not Authorized requests.
	if (req.http.Authorization) {
		return(pass);
	}

	# Pass any requests with the "If-None-Match" header directly.
	if (req.http.If-None-Match) {
		return(pass);
	}

	# Do not cache AJAX requests.
	if (req.http.X-Requested-With == "XMLHttpRequest") {
		return(pass); // DO NOT CACHE
	}

	# Clean up the the encoding header
  	# With vary AcceptEncoding, Varnish will create seperate spaces for each
  	# Don't acccept encodinf images, audio etc...'
    if (req.http.Accept-Encoding) {
    		if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
      		# No point in compressing these
      			unset req.http.Accept-Encoding;
    		} elsif (req.http.Accept-Encoding ~ "gzip") {
      			set req.http.Accept-Encoding = "gzip";
    		} elsif (req.http.Accept-Encoding ~ "deflate") {
      			set req.http.Accept-Encoding = "deflate";
    		} else {
      		# unknown algorithm
      			unset req.http.Accept-Encoding;
    		}
  	}	
	
	# Only cache GET or HEAD requests. This makes sure the POST (and OPTIONS) requests are always passed.
	if (req.method != "GET" && req.method != "HEAD") {
		return (pass); // DO NOT CACHE
	}

	# Static files: Do not cache PDF, XML, ... files (=static & huge and no use caching them - in all Vary: variations!)
	if (req.url ~ "\.(doc|mp3|pdf|tif|tiff|xml)(\?.*|)$") {
		return(pass);
	}

	# Don't cache logged-in users or authors
	if (req.http.Cookie ~ "wp-postpass_|wordpress_logged_in_|comment_author|PHPSESSID") {
		return(pass);
	}
	# don't cache these special pages, e.g. urls with ?nocache or comments, login, regiser, signup, ajax, etc.
	if (req.url ~ "nocache|wp-admin|wp-(comments-post|login|signup|activate|mail|cron)\.php|preview\=true|admin-ajax\.php|xmlrpc\.php|bb-admin|server-status|control\.php|bb-login\.php|bb-reset-password\.php|register\.php") {
		return(pass);
	}

	# Unset the header for static files and cache them
	if (req.url ~ "\.(css|flv|gif|htm|html|ico|jpeg|jpg|js|mp3|mp4|pdf|png|swf|xml|webp|txt)(\?.*|)$") {
		# Remove the query string
		set req.url = regsub(req.url, "\?.*$", "");
		unset req.http.Cookie;
	  	unset req.http.User-Agent;
        unset req.http.Vary;
	}


	# Http header Cookie
	# Remove some cookies (if found).
	# Partially from https://www.varnish-cache.org/docs/4.0/users-guide/increasing-your-hitrate.html#cookies
  	if (req.http.Cookie && !(req.url ~ "wp-(login|admin)")) {
        # 1. Append a semi-colon to the front of the cookie string.
        set req.http.Cookie = ";" + req.http.Cookie;
 
        # 2. Remove all spaces that appear after semi-colons.
        set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
 
        # 3. Match the cookies we want to keep, adding the space we removed
        #    previously, back. (\1) is first matching group in the regsuball.
        set req.http.Cookie = regsuball(req.http.Cookie, ";(SESS[a-z0-9]+|NO_CACHE)=", "; \1=");
 
        # 4. Remove all other cookies, identifying them by the fact that they have
        #    no space after the preceding semi-colon.
        set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
 
        # 5. Remove all spaces and semi-colons from the beginning and end of the
        #    cookie string.
        set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

		# 6. Remove has_js and Google Analytics __* cookies.
		set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_[_a-z]+|has_js)=[^;]*", "");

		# 7. Remove a ";" prefix, if present.
		set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
 
        if (req.http.Cookie == "") {
            # If there are no remaining cookies, remove the cookie header. If there
            # aren't any cookie headers, Varnish's default behavior will be to cache
            # the page.
            unset req.http.Cookie;
        }
        else {
            # If there are any cookies left (a session or NO_CACHE cookie), do not
            # cache the page. Pass it on to Apache directly.
            return (pass);
        }
  	}

	# Varnish v4: vcl_recv must now return hash instead of lookup
	return(hash);
}	

sub vcl_pipe {
	# Force every pipe request to be the first one.
	# https://www.varnish-cache.org/trac/wiki/VCLExamplePipe
	set bereq.http.connection = "close";
}

sub vcl_backend_response {

	if ( (!(bereq.url ~ "nocache|wp-admin|admin|login|wp-(comments-post|login|signup|activate|mail|cron)\.php|preview\=true|admin-ajax\.php|xmlrpc\.php|bb-admin|server-status|control\.php|bb-login\.php|bb-reset-password\.php|register\.php")) || (bereq.method == "GET") ) {
		unset beresp.http.set-cookie;
		set beresp.ttl = 2h;
	}
	# make sure grace is at least 2 minutes
	if (beresp.grace < 2m) {
		set beresp.grace = 2m;
	}
	# catch obvious reasons we can't cache
	if (beresp.http.Set-Cookie) {
		set beresp.ttl = 0s;
	}
	# Varnish determined the object was not cacheable
	if (beresp.ttl <= 0s) {
		set beresp.http.X-Cacheable = "NO:Not Cacheable";
		set beresp.uncacheable = true;
		return (deliver);
	# You don't wish to cache content for logged in users
	} else if (bereq.http.Cookie ~ "wp-postpass_|wordpress_logged_in_|comment_author|PHPSESSID") {
		set beresp.http.X-Cacheable = "NO:Got Session";
		set beresp.uncacheable = true;
		return (deliver);
	# You are respecting the Cache-Control=private header from the backend
	} else if (beresp.http.Cache-Control ~ "private") {
		set beresp.http.X-Cacheable = "NO:Cache-Control=private";
		set beresp.uncacheable = true;
		return (deliver);
	# You are extending the lifetime of the object artificially
	# } else if (beresp.ttl < 300s) {
	# set beresp.ttl = 300s;
	# set beresp.grace = 300s;
	# set beresp.http.X-Cacheable = "YES:Forced";
	# Varnish determined the object was cacheable
	} else {
		set beresp.http.X-Cacheable = "YES";
	}
	# Avoid caching error responses
	if (beresp.status == 404 || beresp.status >= 500) {
		set beresp.ttl = 0s;
		set beresp.grace = 15s;
	}
	# Deliver the content
	return(deliver);

}

sub vcl_hash {
	# Add the browser cookie only if a WordPress cookie found.
	if (req.http.Cookie ~ "wp-postpass_|wordpress_logged_in_|comment_author|PHPSESSID") {
		hash_data(req.http.Cookie);
	}
}

# Deliver cached content
sub vcl_hit {
    return (deliver);
}

# If content is not in cache, fetch from backend
sub vcl_miss {
    return (fetch);
}

sub vcl_deliver {

	if (obj.hits > 0) {
	set resp.http.X-Cache = "HIT";
	 }else {
	set resp.http.X-Cache = "MISS";

	}
}
