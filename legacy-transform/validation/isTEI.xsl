<?xml version="1.0" standalone="yes"?>
<axsl:stylesheet xmlns:axsl="http://www.w3.org/1999/XSL/Transform" xmlns:sch="http://www.ascc.net/xml/schematron" xmlns:exsl="http://exslt.org/common" xmlns:html="http://www.w3.org/1999/xhtml" xmlns:msxsl="urn:schemas-microsoft-com:xslt" xmlns:tei="http://www.tei-c.org/ns/1.0" version="1.0">
  <axsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>
  <axsl:template match="*|@*" mode="schematron-get-full-path">
    <axsl:apply-templates select="parent::*" mode="schematron-get-full-path"/>
    <axsl:text>/</axsl:text>
    <axsl:if test="count(. | ../@*) = count(../@*)">@</axsl:if>
    <axsl:value-of select="name()"/>
    <axsl:text>[</axsl:text>
    <axsl:value-of select="1+count(preceding-sibling::*[name()=name(current())])"/>
    <axsl:text>]</axsl:text>
  </axsl:template>
  <axsl:template match="/">
    <axsl:apply-templates select="/" mode="M3"/>
    <axsl:apply-templates select="/" mode="M4"/>
  </axsl:template>
  <axsl:template match="/*" priority="101" mode="M3">
    <axsl:choose>
      <axsl:when test="namespace-uri(.) = 'http://www.tei-c.org/ns/1.0'"/>
      <axsl:otherwise>
        <p class="schematron-fatal">outermost element is not a TEI element (i.e., is not in the TEI namespace)</p>
        <axsl:text>
</axsl:text>
      </axsl:otherwise>
    </axsl:choose>
    <axsl:choose>
      <axsl:when test="local-name(.) = 'TEI' or local-name(.) = 'teiCorpus'"/>
      <axsl:otherwise>
        <p class="schematron-fatal">outermost element is not 'TEI' or 'teiCorpus'</p>
        <axsl:text>
</axsl:text>
      </axsl:otherwise>
    </axsl:choose>
    <axsl:apply-templates mode="M3"/>
  </axsl:template>
  <axsl:template match="text()" priority="-1" mode="M3"/>
  <axsl:template match="/*" priority="101" mode="M4">
    <axsl:choose>
      <axsl:when test="child::*[local-name(.)='teiHeader']"/>
      <axsl:otherwise>
        <p class="schematron-error">no 'teiHeader' element found as child of outermost element</p>
        <axsl:text>
</axsl:text>
      </axsl:otherwise>
    </axsl:choose>
    <axsl:if test="count( child::*[local-name(.)='teiHeader']   ) &gt; 1">
      <p class="schematron-error">more than one 'teiHeader' element found as child of outermost element</p>
      <axsl:text>
</axsl:text>
    </axsl:if>
    <axsl:apply-templates mode="M4"/>
  </axsl:template>
  <axsl:template match="text()" priority="-1" mode="M4"/>
  <axsl:template match="text()" priority="-1"/>
</axsl:stylesheet>
