Files
-----
tapasBoot.xslt		[4]
tapasEngine.xslt	[4]
data/			[5]
genericTEI2genericXHTML5.xslt [1]
genericTEI2XHTML4noJS.xslt    [2]
xml-to-string.xsl	      [3]

[1] TAPAS version of TEI Boilerplate
[2] The same, but has no javascript
[3] Subroutine of [1] and [2] (and maybe someday [4] :-)
[4] Part of (experimentations enroute to getting us) using SaxonCE to
    process in the browser. Use ../ingestion/in2tfc1.xslt on input
    file to generate file that should be sent to users' browser. It,
    in turn, loads and runs tapasBoot.xslt. It, in turn, loads SaxonCE
    (not included herein) and runs tapasEngine.xslt.
    Currently these files are hard-linked to the versions in Syd's
    ~/public_html/TAPAS/ directory for quick-and-easy testing.
[5] HTML versions of TEI files in ../profiling/data/ along with any
    XML test files already in this directory, generated with
    $ time ( rm -fr /tmp/TFC/ ; mkdir /tmp/TFC/ ; for f in rendering/data/*.xml `find profiling/data -name '*.xml' | egrep '/.*/' | egrep -v 'tei-xsl'` ; do echo "---------$f step 1:" ; t=`dirname $f`/ERASE.ME.xml ; xsltproc ingestion/in2tfc_step1.xslt $f 2> /dev/null > $t ; cp -p $t /tmp/TFC/`basename $f` ; echo "---------$f, step 2:" ; xsltproc --stringparam filePrefix '..' rendering/genericTEI2genericXHTML5.xslt $t | xsltproc rendering/removeExtraneousHashedRefs.xslt - > rendering/data/`basename $f .xml`.xhtml ; rm $t ; done )
    Note: we used to just pipe the output of in2tfc_step1.xslt into
    the input of genericTEI2genericXHTML5.xslt, but that won't work
    now that we want to read other files in using relative URIs.


Page with spreadsheet of features
---- ---- ----------- -- --------
https://docs.google.com/spreadsheet/ccc?key=0AjXUGhoAg9hRdEdWeko0eldFVHlQSUFPUW9FNDdVeGc#gid=0
