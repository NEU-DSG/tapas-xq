<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:tap="http://tapasproject.org/tapas-xq/api"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:xqdoc="http://www.xqdoc.org/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns=""
  xpath-default-namespace="http://www.w3.org/1999/xhtml"
  exclude-result-prefixes="#all"
  version="3.0">
  
<!--
    Generate Markdown documentation for a REST-ful API, using xqDoc's XML representation of a RESTXQ 
    module. This is useful for publishing API documentation on GitHub.
    
    This stylesheet uses xqdoc-to-api-docs.xsl to generate XHTML, then selectively removes structural 
    tags such as <html>, <body>, and <section> in order to produce Markdown.
    
    Ash Clark
    2024
  -->
  
  <!-- We need the "html" output method in order to render any preserved tags. However, the file itself 
    will be text rather than HTML proper. -->
  <xsl:output encoding="UTF-8" indent="no" media-type="text/markdown" method="html"/>
  
  <xsl:import href="xqdoc-to-api-docs.xsl"/>
  
  
 <!--
      PARAMETERS
   -->
  
 <!--
      GLOBAL VARIABLES
   -->
  
  <xsl:variable name="newline" select="'&#xa;'"/>
  
  
  
 <!--
      TEMPLATES, #default mode
   -->
  
  <!-- First, produce XHTML from the xqDoc report. Then, turn that XHTML into Markdown. -->
  <xsl:template match="/">
    <xsl:variable name="xhtmlDocs" as="node()*">
      <xsl:apply-imports/>
    </xsl:variable>
    <xsl:apply-templates select="$xhtmlDocs" mode="markdown"/>
  </xsl:template>
  
  
  
 <!--
      TEMPLATES, markdown mode
   -->
  
  <!-- Most attributes are okay to copy over. -->
  <xsl:template match="@*" mode="markdown">
    <xsl:copy/>
  </xsl:template>
  
  <!-- Strip the namespaces from XHTML elements by default. -->
  <xsl:template match="*" mode="markdown" name="copy-element">
    <xsl:element name="{local-name(.)}">
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:apply-templates mode="#current"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="head | @class" mode="markdown"/>
  
  <xsl:template match="html | body | main | aside | section" mode="markdown">
    <xsl:apply-templates mode="markdown"/>
  </xsl:template>
  
  <!-- We could leave the heading tags as-is, but the Markdown convention of using "#" to indicate 
    heading level is helpful for reading the Markdown as text. -->
  <xsl:template match="h1" mode="markdown">
    <xsl:value-of select="$newline"/>
    <xsl:text># </xsl:text>
    <xsl:value-of select="normalize-space(.)"/>
    <xsl:value-of select="$newline"/>
  </xsl:template>
  
  <xsl:template match="h2" mode="markdown">
    <xsl:value-of select="$newline"/>
    <xsl:text>## </xsl:text>
    <xsl:value-of select="normalize-space(.)"/>
    <xsl:value-of select="$newline"/>
  </xsl:template>
  
  <!-- Don't convert <h2> elements to Markdown if their IDs would be lost on conversion. -->
  <xsl:template match="h2[@id]" mode="markdown" priority="2">
    <xsl:value-of select="$newline"/>
    <xsl:call-template name="copy-element"/>
    <xsl:value-of select="$newline"/>
  </xsl:template>
  
  <xsl:template match="h3" mode="markdown">
    <xsl:value-of select="$newline"/>
    <xsl:text>### </xsl:text>
    <xsl:value-of select="normalize-space(.)"/>
    <xsl:value-of select="$newline"/>
  </xsl:template>
  
  <xsl:template match="p" mode="markdown">
    <xsl:value-of select="$newline"/>
    <xsl:apply-templates mode="#current"/>
    <xsl:value-of select="$newline"/>
  </xsl:template>
  
  <!-- We'll keep the <table> mostly as-is, rather than try to convert it to Markdown. -->
  <xsl:template match="table" mode="markdown">
    <xsl:value-of select="$newline"/>
    <xsl:element name="table">
      <xsl:apply-templates mode="#current"/>
    </xsl:element>
    <xsl:value-of select="$newline"/>
  </xsl:template>
  
</xsl:stylesheet>