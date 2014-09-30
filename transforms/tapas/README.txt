Transform for metadata extraction
--------- --- -------- ----------
* tfc.xsl = Reads in input TEI and writes out a Tapas Friendly Copy
  	    thereof. This TFC is what we use internally for most stuff.
* teiHeader2dc1.xsl = should not be used any more (as tfc.xsl does a
  		      better job), but I think it still is. -- Syd,
  		      2014-09-28

Transforms for TAPAS Generic reading interface
---------- --- ----- ------- ------- ---------
* h1.xsl = does most the work
* h2.xsl = remove some extraneous attrs
* h3.xsl = currently a no-op placeholder
* h4.xsl = currently a no-op placeholder
* h5.xsl = currently a no-op placeholder
* xml-to-string.xsl = subroutine of Boilerplate that renders XML
  		      halfway decently; currently unused
