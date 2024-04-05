<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:tap="http://tapasproject.org/tapas-xq/api"
  xmlns:xqdoc="http://www.xqdoc.org/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns=""
  xpath-default-namespace="http://www.xqdoc.org/1.0"
  exclude-result-prefixes="#all"
  version="3.0">
  
<!--
    Display HTML documentation, using an XQDoc XML representation of a RESTXQ module.
    
    Ash Clark
    2024
  -->
  
  <xsl:output encoding="UTF-8" indent="yes" method="html" omit-xml-declaration="no"/>
  
 <!--  PARAMETERS  -->
  
  <xsl:param name="html-title" select="'TAPAS-xq API'" as="xs:string?"/>
  
  
  
 <!--  GLOBAL VARIABLES  -->
  
  <xsl:variable name="date-updated" select="//control/date/xs:dateTime(.)" as="xs:dateTime?"/>
  
  
  
 <!--  FALLBACK TEMPLATES  -->
  
  <xsl:template match="*" mode="#default">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="@* | text() | comment() | processing-instruction()" mode="#default"/>
  
  
  
 <!--  TEMPLATES, #default mode  -->
  
  <xsl:template match="/">
    <html lang="en">
      <head>
        <title>
          <xsl:value-of select="$html-title"/>
        </title>
        <style><![CDATA[
          section { margin: 1.5rem 0 2rem; }
          .endpoint { font-size: 1.125em; }
          .endpoint .param { color: #cb0000; }
          dt.param {
            font-family: monospace;
            font-size: 1.1em;
          }
          dd + dt.param { margin-top: 0.35em; }
        ]]></style>
      </head>
      <body>
        <h1>API documentation</h1>
        <div>
          <h2>Request endpoints</h2>
          <xsl:apply-templates select="//functions"/>
        </div>
      </body>
    </html>
  </xsl:template>
  
  <!-- For API documentation, we're only interested in functions with RESTXQ annotations. -->
  <xsl:template match="function"/>
  <xsl:template match="function[.//annotation[@name eq 'rest:path']]" priority="2">
    <xsl:variable name="localName" select="replace(name, '^\w+:', '')"/>
    <xsl:variable name="headingId" select="'section_'||$localName"/>
    <xsl:variable name="humanName" as="xs:string">
      <xsl:variable name="nameWithSpaces" select="replace($localName, '[_-]', ' ')"/>
      <xsl:value-of 
        select="upper-case(substring($nameWithSpaces,1,1))||substring($nameWithSpaces,2)"/>
    </xsl:variable>
    <section aria-labelledby="{$headingId}">
      <h3 id="{$headingId}">
        <xsl:value-of select="$humanName"/>
      </h3>
      <p><code class="endpoint">
        <xsl:call-template name="get-http-method"/>
        <xsl:text> </xsl:text>
        <xsl:variable name="regexp" select="'\{\$([\w_-]+)\}'"/>
        <xsl:analyze-string select=".//annotation[@name eq 'rest:path']/*/string(.)" 
           regex="{$regexp}">
          <xsl:matching-substring>
            <strong class="param"><xsl:value-of select="regex-group(1)"/></strong>
          </xsl:matching-substring>
          <xsl:non-matching-substring>
            <xsl:value-of select="."/>
          </xsl:non-matching-substring>
        </xsl:analyze-string>
      </code></p>
      
      <xsl:apply-templates select="comment/description"/>
      <xsl:if test="exists(comment/param)">
        <dl>
          <xsl:apply-templates select="comment/param"/>
        </dl>
      </xsl:if>
    </section>
  </xsl:template>
  
  <xsl:template match="comment/description">
    <xsl:variable name="paragraphsMarked" as="node()*">
      <xsl:apply-templates mode="mark-paragraph-boundaries"/>
    </xsl:variable>
    <xsl:for-each-group select="$paragraphsMarked" 
       group-ending-with="*:br[@class eq 'paragraph-boundary']">
      <p>
        <xsl:apply-templates select="current-group()" mode="remove-paragraph-boundaries"/>
      </p>
    </xsl:for-each-group>
  </xsl:template>
  
  <xsl:template match="comment/param">
    <dt class="param">
      <xsl:value-of select="substring-before(., ' ')"/>
    </dt>
    <dd>
      <xsl:value-of select="substring-after(., ' ')"/>
    </dd>
  </xsl:template>
  
  
  
 <!--  TEMPLATES, "mark-paragraph-boundaries" mode  -->
  
  <!-- Two or more newlines in a text node are changed into <br/>s with a special class. These can be 
    used to group text content into <p>s. -->
  <xsl:template match="text()" mode="mark-paragraph-boundaries">
    <xsl:analyze-string select="." regex="\n\n+">
      <xsl:matching-substring>
        <br class="paragraph-boundary" />
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:template>
  
  <!-- Reproduce existing tags in the description, sans namespace. -->
  <xsl:template match="*" mode="mark-paragraph-boundaries">
    <xsl:element name="{local-name()}">
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates mode="#current"/>
    </xsl:element>
  </xsl:template>
  
  
  
 <!--  TEMPLATES, "remove-paragraph-boundaries" mode  -->
  
  
  <xsl:template match="*" mode="remove-paragraph-boundaries">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="text()" mode="remove-paragraph-boundaries">
    <xsl:copy/>
  </xsl:template>
  
  <!-- Remove any paragraph boundaries inserted from "mark-paragraph-boundaries" mode. -->
  <xsl:template match="Q{}br[@class eq 'paragraph-boundary']" priority="2" mode="remove-paragraph-boundaries"/>
  
  
  
 <!--  NAMED TEMPLATES  -->
  
  <xsl:template name="get-http-method">
    <xsl:variable name="methodAnnotation" 
      select=".//annotation[@name = ('rest:GET', 'rest:PUT', 'rest:POST', 'rest:DELETE', 'rest:HEAD')]" as="node()*"/>
    <xsl:value-of select="$methodAnnotation/@name/substring-after(., 'rest:')"/>
  </xsl:template>
  
  
 <!--  FUNCTIONS  -->
  
  
</xsl:stylesheet>