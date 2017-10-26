<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron" queryBinding="xpath2">
  <title>TAPAS generic is-it-a-TEI-file test</title>
  <ns uri="http://www.tei-c.org/ns/1.0" prefix="tei"/>
  
  <!-- intended as the first check on an XML file being ingested as a -->
  <!-- TEI file into TAPAS -->

  <!-- To convert this to XSLT2 using XSLT2 run it through -->
  <!-- https://raw.githubusercontent.com/Schematron/schematron/master/trunk/schematron/code/iso_schematron_skeleton_for_saxon.xsl -->
  <!-- (I.e., clone https://github.com/Schematron/schematron.git and issue something like -->
  <!-- $ saxon.bash /PATH/TO/schematron/trunk/schematron/code/iso_schematron_skeleton_for_saxon.xsl resources/isTEI.sch > resources/isTEI.xsl -->

  <p>Written 2014-03-16 by Syd Bauman for TAPAS. Copyleft.</p>
  <p>Re-written 2015-08-19 by Syd w/ Ashley</p>
  <p>Updated 2017-10-26 by Syd:
     * remove extranous "one" test
     * add test for &lt;script>, as that is a vulnerability
     * test that &lt;teiHeader> exists as any child of root element,
       not just first child of root element.</p>
  
  <pattern id="TAPAS01-outermost-element">
    <rule context="/*" role="fatal">
      <assert test="namespace-uri(.) eq 'http://www.tei-c.org/ns/1.0'">outermost element is not a TEI element (i.e., is not in the TEI namespace)</assert>
      <assert test="self::*[ local-name(.) eq 'TEI' ]">outermost element is not 'TEI'</assert>
      <report test="self::tei:teiCorpus">Sorry, TAPAS cannot handle corpora (yet)</report>
    </rule>
  </pattern>
  
  <!-- handle case where <teiHeader> exists but is not 1st child, no? -->
  <pattern id="TAPAS02-teiHeader">
    <rule context="/tei:TEI" role="fatal">
      <assert test="tei:teiHeader">there must be a 'teiHeader' child of the outermost TEI element in order for TAPAS to know where to find certain metadata</assert>
      <report test="count( child::tei:teiHeader ) > 1">more than one 'teiHeader' element found as child of outermost TEI element</report>
    </rule>
  </pattern>
  
</schema>
