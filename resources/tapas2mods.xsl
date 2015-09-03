<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:mods="http://www.loc.gov/mods/v3"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xpath-default-namespace="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="#all"
  version="2.0">
  
  <xsl:import href="TAPAS2MODSminimal.xsl"/>
  
  <!-- The title of the item as it appears on TAPAS. -->
  <xsl:param name="displayTitle" select="''" as="xs:string"/>
  <!-- A string with each author's name concatenated by a '|'. -->
  <xsl:param name="displayAuthors" select="''" as="xs:string"/>
  <!-- A string with each contributor's name concatenated by a '|'. -->
  <xsl:param name="displayContributors" select="''" as="xs:string"/>
  <!-- The date corresponding to the item in the TAPAS timeline. xs:date format preferred. -->
  <xsl:param name="timelineDate" select="''"/>
  
  <xsl:variable name="displayFields">
    <xsl:if test="$displayTitle">
      <mods:titleInfo displayLabel="TAPAS title:">
        <xsl:call-template name="constructTitle">
          <xsl:with-param name="inputTitle" select="normalize-space($displayTitle)"/>
        </xsl:call-template>
      </mods:titleInfo>
    </xsl:if>
    <xsl:if test="$displayAuthors">
      <xsl:variable name="autRole">
        <xsl:call-template name="setRole">
          <xsl:with-param name="term" select="'Author'"/>
          <xsl:with-param name="authority" select="'marcrelator'"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:for-each select="tokenize($displayAuthors,'\|')">
        <mods:name displayLabel="TAPAS author:">
          <mods:namePart><xsl:value-of select="normalize-space(.)"/></mods:namePart>
          <xsl:copy-of select="$autRole"/>
        </mods:name>
      </xsl:for-each>
    </xsl:if>
    <xsl:if test="$displayContributors">
      <xsl:variable name="ctrbRole">
        <xsl:call-template name="setRole">
          <xsl:with-param name="term" select="'Contributor'"/>
          <xsl:with-param name="authority" select="'marcrelator'"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:for-each select="tokenize($displayContributors,'\|')">
        <mods:name displayLabel="TAPAS contributor:">
          <mods:namePart><xsl:value-of select="normalize-space(.)"/></mods:namePart>
          <xsl:copy-of select="$ctrbRole"/>
        </mods:name>
      </xsl:for-each>
    </xsl:if>
    <xsl:if test="$timelineDate">
      <mods:note type="date" displayLabel="TAPAS timeline date:">
        <xsl:value-of select="if ($timelineDate castable as xs:date) then xs:date($timelineDate)
                              else $timelineDate"/>
      </mods:note>
    </xsl:if>
  </xsl:variable>
  
  <xsl:template match="teiHeader">
    <xsl:copy-of select="$displayFields"/>
    <xsl:apply-templates/>
  </xsl:template>
  
</xsl:stylesheet>