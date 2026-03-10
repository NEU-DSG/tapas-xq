<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:tap="http://tapasproject.org/tapas-xq/api"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:xqdoc="http://www.xqdoc.org/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns="http://www.w3.org/1999/xhtml"
  xpath-default-namespace="http://www.xqdoc.org/1.0"
  exclude-result-prefixes="#all"
  version="3.0">
  
<!--
    Generate HTML documentation for a REST-ful API, using xqDoc's XML representation of a RESTXQ module.
    
    Ash Clark
    2024
  -->
  
  <xsl:output encoding="UTF-8" indent="yes" method="xhtml" omit-xml-declaration="no"/>
  
 <!--
      PARAMETERS
   -->
  
  <!-- The title of the output webpage. -->
  <xsl:param name="html-title" select="'TAPAS-xq API documentation'" as="xs:string?"/>
  
  <!-- A URL to the XQuery which is considered the source of the xqDoc XML. If a URL is provided, a link 
    to the XQuery is included along with the generation statement. -->
  <xsl:param name="source-code-url" as="xs:string?"/>
  
  
  
 <!--
      GLOBAL VARIABLES
   -->
  
  <!-- When the xqDoc XML was generated. We could also use current-dateTime() to be more precise about 
    when this XSLT is run. However, if the xqDoc XML was generated some time before transformation, it 
    is more useful to know how up-to-date the xqDoc is to its source XQuery. It's not as useful to know 
    when this XSLT produced XHTML. -->
  <xsl:variable name="date-generated" select="//control/date/xs:dateTime(.)" as="xs:dateTime?"/>
  
  
  
 <!--
      FALLBACK TEMPLATES
   -->
  
  <xsl:template match="*" mode="#default">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>
  
  <xsl:template match="@* | text() | comment() | processing-instruction()" mode="#default"/>
  
  
  
 <!--
      TEMPLATES, #default mode
   -->
  
  <xsl:template match="/*">
    <html lang="en">
      <head>
        <title>
          <xsl:value-of select="$html-title"/>
        </title>
        <xsl:call-template name="set-styling"/>
      </head>
      <body>
        <aside>
          <p>
            <xsl:text>This documentation was generated from its </xsl:text>
            <xsl:choose>
              <xsl:when test="exists($source-code-url)">
                <a href="{$source-code-url}">source code</a>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>source code</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:text> on </xsl:text>
            <xsl:value-of 
              select="format-dateTime($date-generated, '[MNn] [D1o], [Y], [h]:[m] [P] [z]')"/>
            <xsl:text>.</xsl:text>
          </p>
        </aside>
        <main>
          <h1>
            <xsl:value-of select="$html-title"/>
          </h1>
          <xsl:apply-templates select="//module/comment"/>
          <h2 id="all-endpoints">Request endpoints</h2>
          <xsl:apply-templates select="//functions"/>
        </main>
      </body>
    </html>
  </xsl:template>
  
  <xsl:template match="module/comment">
    <xsl:apply-templates/>
  </xsl:template>
  
  <!-- For API documentation, we're only interested in functions with RESTXQ annotations. -->
  <xsl:template match="function"/>
  <xsl:template match="function[.//annotation[@name eq 'rest:path']]" priority="2">
    <xsl:variable name="localName" select="replace(name, '^\w+:', '')"/>
    <xsl:variable name="headingId" select="'section_'||$localName"/>
    <xsl:variable name="humanName" as="xs:string">
      <xsl:variable name="nameWithSpaces" select="replace($localName, '[_-]', ' ')"/>
      <xsl:value-of select="upper-case(substring($nameWithSpaces,1,1))
                            || substring($nameWithSpaces,2)"/>
    </xsl:variable>
    <xsl:variable name="endpointPath" as="node()*">
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
    </xsl:variable>
    <section aria-labelledby="{$headingId}">
      <h3 id="{$headingId}">
        <xsl:value-of select="$humanName"/>
      </h3>
      <!-- The API endpoint is the HTTP method and URL to which a response is mapped, for example:
          GET /tapas-xq
        -->
      <p><code class="endpoint">
        <xsl:call-template name="get-http-method"/>
        <xsl:text> </xsl:text>
        <xsl:copy-of select="$endpointPath"/>
      </code></p>
      <xsl:apply-templates select="comment">
        <!-- We generate the mapping of function to API parameters here and tunnel it to the templates 
          that will later need it. -->
        <xsl:with-param name="api-mapping" as="map(*)?" tunnel="yes">
          <xsl:call-template name="set-parameters-mapping"/>
        </xsl:with-param>
      </xsl:apply-templates>
    </section>
  </xsl:template>
  
  <xsl:template match="function/comment">
    <xsl:apply-templates select="description"/>
    <xsl:apply-templates select="return"/>
    <xsl:if test="exists(param)">
      <table class="function-params">
        <caption>Request settings</caption>
        <thead>
          <tr>
            <th style="min-width:10%;">Name</th>
            <th>Description</th>
            <th>Where to set value</th>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates select="param"/>
        </tbody>
      </table>
    </xsl:if>
  </xsl:template>
  
  <!-- The xqDoc description and `@return` tag may contain paragraphs, marked by 2 or more newlines. We 
    process these text nodes so they can be marked with <p>. -->
  <xsl:template match="comment/description | comment/return">
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
    <xsl:param name="api-mapping" as="map(*)?" tunnel="yes"/>
    <xsl:variable name="paramName" select="substring-before(., ' ')"/>
    <xsl:variable name="paramMap" select="$api-mapping?($paramName)"/>
    <xsl:variable name="isRepresentedInApi" select="exists($paramMap?api-setting-type)"/>
    <tr>
      <!-- The HTTP parameter name, if applicable. Otherwise, use the function's parameter name. (In 
        general, the HTTP parameter name should exactly match the function's parameter. However, it may 
        be useful to have a public-facing, broadly-interpretable version of the name, as well as an 
        internal flavor of the name for use within the XQuery module.) -->
      <th scope="row" class="param">
        <xsl:choose>
          <xsl:when test="$isRepresentedInApi and exists($paramMap?api-setting-key)">
            <xsl:value-of select="$paramMap?api-setting-key"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$paramName"/>
          </xsl:otherwise>
        </xsl:choose>
      </th>
      <!-- The xqDoc description of that parameter. -->
      <td>
        <xsl:value-of select="substring-after(., ' ')"/>
      </td>
      <!-- Where the parameter value should be set in the API request. -->
      <td>
        <xsl:if test="$isRepresentedInApi">
          <xsl:value-of select="$paramMap?api-setting-type"/>
        </xsl:if>
      </td>
    </tr>
  </xsl:template>
  
  
  
 <!--
      TEMPLATES, "mark-paragraph-boundaries" mode
   -->
  
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
  
  <!-- Add a short introduction to the beginning of the `@return` value. -->
  <xsl:template match="return/node()[1]" mode="mark-paragraph-boundaries" priority="3">
    <xsl:text>This endpoint returns </xsl:text>
    <xsl:next-match/>
  </xsl:template>
  
  
  
 <!--
      TEMPLATES, "remove-paragraph-boundaries" mode
   -->
  
  
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
  <xsl:template match="xhtml:br[@class eq 'paragraph-boundary']" priority="2" 
     mode="remove-paragraph-boundaries"/>
  
  
  
 <!--
      NAMED TEMPLATES
   -->
  
  <xsl:template name="get-http-method">
    <xsl:variable name="methodAnnotation" 
      select=".//annotation[@name = ('rest:GET', 'rest:PUT', 'rest:POST', 'rest:DELETE', 'rest:HEAD')]" as="node()*"/>
    <xsl:value-of select="$methodAnnotation/@name/substring-after(., 'rest:')"/>
  </xsl:template>
  
  
  <!-- Generate a map of the current function's parameters along with their RESTXQ parameter 
    equivalents. -->
  <xsl:template name="set-parameters-mapping">
    <xsl:variable name="annotations" select=".//annotation"/>
    <xsl:map>
      <xsl:for-each select="parameters/parameter">
        <xsl:variable name="paramNameRegexp" select="'\{\$'||name||'\}'"/>
        <xsl:variable name="annotationMatch" 
          select="$annotations[literal[matches(., $paramNameRegexp)]]"/>
        <xsl:variable name="annotationType" 
          select="if ( empty($annotationMatch) ) then ()
                  else if ( $annotationMatch/@name eq 'rest:path' ) then
                    'URL'
                  else if ( $annotationMatch/@name eq 'rest:form-param' ) then
                    'form parameter'
                  else if ( $annotationMatch/@name eq 'rest:query-param' ) then
                    'query parameter'
                  else ()"/>
        <xsl:variable name="annotationKey" 
           select="if ( $annotationType = ('form parameter', 'query parameter') ) then 
                     literal[1]/string()
                   else ()"/>
        <xsl:map-entry key="name/string()"
           select="map {
                      'api-setting-key': $annotationKey,
                      'api-setting-type': $annotationType,
                      'datatype': type/string()
                    }"/>
      </xsl:for-each>
    </xsl:map>
  </xsl:template>
  
  
  <!-- Define CSS for the HTML documentation. -->
  <xsl:template name="set-styling">
    <style><![CDATA[
          body {
            font-family: Verdana, Helvetica, Arial, sans-serif;
            margin: 0 0 1rem;
            padding: 0 2rem;
          }
          section { margin: 1.5rem 0 2rem; }
          .endpoint { font-size: 1.125em; }
          .endpoint .param { color: #cb0000; }
          .param {
            font-family: monospace;
            font-size: 1.1em;
          }
          table.function-params { 
            border: thin solid #333;
            border-collapse: collapse;
            margin: 0 1rem;
            width: 100%;
          }
          caption {
            font-size: 1.1em;
            padding: 0.25em 0 0.5em;
          }
          th, td {
            padding: 0.35rem;
            vertical-align: baseline;
          }
          thead th { border-bottom: thin solid gray; }
          th.param { text-align: right; }
          td { padding-left: 0.5rem; }
          dd + dt.param { margin-top: 0.35rem; }
        ]]></style>
  </xsl:template>
  
  
</xsl:stylesheet>