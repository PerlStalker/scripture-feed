scripture-feed
==============

Creates a feed that can be added to an RSS reader for daily scripture
study.

Requires a copy of version 3.0 of the scriptures database from [The
Mormon Documentation Project](http://scriptures.nephi.org/). The
database is in the public domain and a copy has been included.

Docker
======

By default, `gen_scripture_feed.pl` writes to
`/usr/share/nginx/html/Scriptures`. This matches
[the official nginx docker repo](https://registry.hub.docker.com/_/nginx/). You
can play tricks with the docker volumes to place it wherever you need
it.
