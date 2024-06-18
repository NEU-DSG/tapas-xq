<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:webapp="http://xmlns.jcp.org/xml/ns/javaee"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns="http://xmlns.jcp.org/xml/ns/javaee"
  xpath-default-namespace="http://xmlns.jcp.org/xml/ns/javaee"
  exclude-result-prefixes="#all"
  version="3.0">
  
<!--
    Modify the BaseX web.xml configuration for use with TAPAS-xq.
    
    Ash Clark
    2024
  -->
  
  <xsl:output encoding="UTF-8" indent="yes" method="xml" omit-xml-declaration="no"/>
  
  
 <!--
      FALLBACK TEMPLATES
   -->
  
  <xsl:template match="*" mode="#all">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:apply-templates mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="@* | text() | comment() | processing-instruction()" mode="#all">
    <xsl:copy/>
  </xsl:template>
  
  
 <!--
      TEMPLATES, #default mode
   -->
  
  <!-- Put each leading processing instruction on its own line. -->
  <xsl:template match="/processing-instruction()">
    <xsl:if test="position() = 1">
      <xsl:text>&#x0A;</xsl:text>
    </xsl:if>
    <xsl:copy/>
    <xsl:text>&#x0A;</xsl:text>
  </xsl:template>
  
  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>
  
  <!-- After the commented-out BaseX options, add some actual ones. -->
  <xsl:template match="comment()[contains(., 'https://docs.basex.org/wiki/Options')]">
    <xsl:copy-of select="."/>
    <xsl:comment> By default, index attributes that look like IDs or keys. </xsl:comment>
    <context-param>
      <param-name>org.basex.attrinclude</param-name>
      <param-value>*:id,ID,key</param-value>
    </context-param>
    <xsl:comment> By default, index diacritics. </xsl:comment>
    <context-param>
      <param-name>org.basex.diacritics</param-name>
      <param-value>true</param-value>
    </context-param>
    <xsl:comment> By default, serialized documents aren't indented. </xsl:comment>
    <context-param>
      <param-name>org.basex.serializer</param-name>
      <param-value>indent=no</param-value>
    </context-param>
    <xsl:comment> By default, BaseX will skip over files that it can't parse, rather than
      returning an error. </xsl:comment>
    <context-param>
      <param-name>org.basex.skipcorrupt</param-name>
      <param-value>true</param-value>
    </context-param>
  </xsl:template>
  
  <!-- Remove the default user for RESTXQ. -->
  <xsl:template match="servlet[servlet-name eq 'RESTXQ']/init-param">
    <xsl:comment> Removed default user. </xsl:comment>
  </xsl:template>
  
</xsl:stylesheet>