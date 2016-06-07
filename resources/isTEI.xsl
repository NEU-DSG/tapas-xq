<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:sch="http://www.ascc.net/xml/schematron"
                xmlns:exsl="http://exslt.org/common"
                xmlns:msxsl="urn:schemas-microsoft-com:xslt"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:xi="http://www.w3.org/2001/XInclude"
                version="2.0">
   <xsl:output method="text"/>
   <xsl:template match="*|@*" mode="schematron-get-full-path">
      <xsl:apply-templates select="parent::*" mode="schematron-get-full-path"/>
      <xsl:text>/</xsl:text>
      <xsl:if test="count(. | ../@*) = count(../@*)">@</xsl:if>
      <xsl:value-of select="name()"/>
      <xsl:text>[</xsl:text>
      <xsl:value-of select="1+count(preceding-sibling::*[name()=name(current())])"/>
      <xsl:text>]</xsl:text>
   </xsl:template>
   <xsl:template match="/">
      <xsl:apply-templates select="/" mode="M5"/>
      <xsl:apply-templates select="/" mode="M6"/>
      <xsl:apply-templates select="/" mode="M7"/>
      <xsl:apply-templates select="/" mode="M8"/>
   </xsl:template>
   <xsl:template match="/*[namespace-uri(.) != 'http://www.tei-c.org/ns/1.0']"
                 priority="101"
                 mode="M5">
      <xsl:choose>
         <xsl:when test="true()"/>
         <xsl:otherwise>
            <xsl:message>Outermost element is not a TEI element (i.e., is not in the TEI namespace)</xsl:message>
         </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates mode="M5"/>
   </xsl:template>
   <xsl:template match="text()" priority="-1" mode="M5"/>
   <xsl:template match="/*" priority="101" mode="M6">
      <xsl:choose>
         <xsl:when test="namespace-uri(.) = 'http://www.tei-c.org/ns/1.0'"/>
         <xsl:otherwise>
            <xsl:message>
               <xsl:text>Fatal:</xsl:text>outermost element is not a TEI element (i.e., is not in the TEI namespace)</xsl:message>
         </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
         <xsl:when test="self::tei:TEI"/>
         <xsl:otherwise>
            <xsl:message>
               <xsl:text>Fatal:</xsl:text>Outermost element is not 'TEI'</xsl:message>
         </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="self::tei:teiCorpus">
         <xsl:message>
            <xsl:text>Fatal:</xsl:text>Sorry, TAPAS cannot handle corpora (yet)</xsl:message>
      </xsl:if>
      <xsl:apply-templates mode="M6"/>
   </xsl:template>
   <xsl:template match="text()" priority="-1" mode="M6"/>
   <xsl:template match="/*" priority="101" mode="M7">
      <xsl:choose>
         <xsl:when test="child::*[1][self::tei:teiHeader]"/>
         <xsl:otherwise>
            <xsl:message>
               <xsl:text>Fatal:</xsl:text>'teiHeader' is not the first child of the outermost TEI element</xsl:message>
         </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="count( child::tei:teiHeader ) &gt; 1">
         <xsl:message>
            <xsl:text>Fatal:</xsl:text>More than one 'teiHeader' element found as child of outermost TEI element</xsl:message>
      </xsl:if>
      <xsl:apply-templates mode="M7"/>
   </xsl:template>
   <xsl:template match="text()" priority="-1" mode="M7"/>
   <xsl:template match="//xi:*" priority="101" mode="M8">
      <xsl:if test="matches(@href,'^/')">
         <xsl:message>
            <xsl:text>Fatal:</xsl:text>An XInclude's @href must not begin with "/"</xsl:message>
      </xsl:if>
      <xsl:if test="contains(@xpointer,'doc(')">
         <xsl:message>
            <xsl:text>Fatal:</xsl:text>An XInclude's @xpointer must not contain the "doc()" XPath function</xsl:message>
      </xsl:if>
      <xsl:if test="contains(@xpointer,'collection(')">
         <xsl:message>
            <xsl:text>Fatal:</xsl:text>An XInclude's @xpointer must not contain the "collection()" XPath function</xsl:message>
      </xsl:if>
      <xsl:apply-templates mode="M8"/>
   </xsl:template>
   <xsl:template match="text()" priority="-1" mode="M8"/>
   <xsl:template match="text()" priority="-1"/>
</xsl:stylesheet>
