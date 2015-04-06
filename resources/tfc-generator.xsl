<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tapas="http://www.wheatoncollege.edu/TAPAS/1.0"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs"
  version="2.0">
  
  <!-- Read in a random TEI (P5) file, and write out a TAPAS-friendly copy -->
  <!-- of the same, step 1: -->
  <!-- * insert new <tapas:metadata> element with pre-digested metadata -->
  <!-- * strip off paths from relative URLs -->
  <!-- * change PI names so that information is retained, but processors -->
  <!--   don't actually act on them -->
  <!-- * for elements that have data.pointer attrs, add a hashed version thereof -->
  
  <xsl:output method="xml" indent="yes"/>
  <!-- special chars -->
  <xsl:variable name="apos" select='"&apos;"'/>
  <!-- URL characters (per RFC 2396) that are not XML Name characters divided into three -->
  <!-- sets. Note that we think of colon (":") as a non-XML Name character. -->
  <xsl:variable name="URIc1" select="concat('!#$%&amp;', $apos )"/>
  <xsl:variable name="URIc2" select="'()*+,/'"/>
  <xsl:variable name="URIc3" select="':;=?@~'"/>
  
  <!-- ******************** -->
  <!-- main top-level stuff -->
  <!-- ******************** -->
  
  <!-- routine identity transform: copy everything not handled separately below -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>