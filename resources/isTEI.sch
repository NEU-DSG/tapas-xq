<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://www.ascc.net/xml/schematron">  
  <title>TAPAS generic is-it-a-TEI-file test</title>
  <ns uri="http://www.tei-c.org/ns/1.0" prefix="tei"/>
  
  <!-- intended as the first check on an XML file being ingested as a -->
  <!-- TEI file into TAPAS -->
  
  <p>Written 2014-03-16 by Syd Bauman for TAPAS. Copyleft.</p>
  <p>Re-written 2015-08-19 by Syd w/ Ashley</p>
  
  <pattern name="one">
    <rule context="/*[namespace-uri(.) != 'http://www.tei-c.org/ns/1.0']">
      <assert test="true()">outermost element is not a TEI element (i.e., is not in the TEI namespace)</assert>
    </rule>
  </pattern>
  
  
  <pattern name="TAPAS01-outermost-element">
    <rule context="/*" role="fatal">
      <assert test="namespace-uri(.) = 'http://www.tei-c.org/ns/1.0'">outermost element is not a TEI element (i.e., is not in the TEI namespace)</assert>
      <!-- assert test="local-name(.) = 'TEI' or local-name(.) = 'teiCorpus'">outermost element is not 'TEI' or 'teiCorpus'</assert -->
      <assert test="self::tei:TEI">outermost element is not 'TEI'</assert>
      <report test="self::tei:teiCorpus">Sorry, TAPAS cannot handle corpora (yet)</report>
    </rule>
  </pattern>
  
  <pattern name="TAPAS02-teiHeader">
    <rule context="/*" role="fatal">
      <assert test="child::*[1][self::tei:teiHeader]">'teiHeader' is not the first child of the outermost TEI element</assert>
      <report test="count( child::tei:teiHeader ) > 1">more than one 'teiHeader' element found as child of outermost TEI element</report>
    </rule>
  </pattern>
  
</schema>
