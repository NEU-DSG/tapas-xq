<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tapas="http://www.wheatoncollege.edu/TAPAS/1.0"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" 
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns="http://www.tei-c.org/ns/1.0"
  exclude-result-prefixes="xs tei"
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
  <xsl:variable name="tei-namespace" select="'http://www.tei-c.org/ns/1.0'"/>
  
  <!-- ******************** -->
  <!-- main top-level stuff -->
  <!-- ******************** -->
  
  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>
  
  <!-- routine identity transform: copy everything not handled separately below -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- handle <TEI> element (note: <teiCorpus> may have been uppermost element, -->
  <!-- if so it would have been copied by identity) -->
  <xsl:template match="tei:TEI">
    <xsl:call-template name="insert-PIs"/>
    <!-- insert TAPAS metadata before <text>; this fails miserably if there -->
    <!-- is no <text>; or if there are nodes between multiple <text>s (which -->
    <!-- would be invalid TEI, only 1 <text> is allowed) -->
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="node()[following-sibling::tei:text]"/>
      <xsl:call-template name="tapasHeader"/>
      <xsl:apply-templates select="tei:text"/>
      <xsl:apply-templates select="node()[preceding-sibling::tei:text]"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template name="tapasHeader">
    <tapas:metadata>
      <!-- Cutting out the DC metadata in favor of MODS. -->
      <!--<xsl:call-template name="get-title"/>
      <xsl:call-template name="get-creator"/>
      <xsl:call-template name="get-contributor"/>
      <xsl:call-template name="get-date"/>
      <xsl:call-template name="get-language"/>
      <xsl:call-template name="get-rights"/>
      <xsl:call-template name="get-source"/>-->
      <!-- xsl:call-template name="get-subject"/ -->
      <xsl:call-template name="get-transforms"/>
    </tapas:metadata>
  </xsl:template>
  
  <!-- ******************** -->
  <!-- tapasHeader routines -->
  <!-- ******************** -->
  <xsl:template name="get-transforms">
    <tapas:transforms>
      <tapas:transform name="TAPAS_Boilerplate"/>
      <tapas:transform name="TAPAS_Boilerplate_NoJS"/>
    </tapas:transforms>
  </xsl:template>
  
  <xsl:template name="drupal-permissions">
    
  </xsl:template>
  
  <!-- *********** -->
  <!-- PI routines -->
  <!-- *********** -->
  
  <xsl:template match="processing-instruction()[
    name()='xml-model' or
    name()='oxygen' or 
    name()='xml-stylesheet'
    ]">
    <xsl:variable name="oldName" select="name()"/>
    <xsl:variable name="newName">
      <xsl:choose>
        <xsl:when test="starts-with($oldName,'xml-')">
          <xsl:value-of select="concat('tapas',substring($oldName,4))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="concat('tapas-',$oldName)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:processing-instruction name="{$newName}" select="."/>
  </xsl:template>
  
  <xsl:template name="insert-PIs">
    <xsl:processing-instruction name="xml-stylesheet">
      <!-- HEY SYD: Is "tapasBoot.xslt" actually a real stylesheet? I couldn't find it in the legacy Drupal code anywhere. (Though I suppose it could be represented in the database.) ~Ashley -->
      <xsl:text>type="text/xsl" href="tapasBoot.xslt"</xsl:text>
    </xsl:processing-instruction>
  </xsl:template>
  
  <!-- ************************** -->
  <!-- data manipulation routines -->
  <!-- ************************** -->
  
  <!-- Move janus tags to type= of <persName> when used inside <person>. -->
  <!-- As current written this drops the type= of the <persName>. OK for -->
  <!-- for now, as there are none. But we should fix that someday, likely -->
  <!-- by using subtype= or data-tapas-type=. -->
  
  <!-- HEY SYD: Wouldn't other interesting attributes be lost with the original
    persName? What necessitates the removal of choice? -->
  <xsl:template match="tei:person/tei:persName[tei:choice]">
    <!--<xsl:apply-templates select="tei:choice/*" mode="makemeapersname"/>-->
    <xsl:for-each select="tei:choice/(tei:abbr|tei:expan|tei:sic|tei:corr|tei:orig|tei:reg)">
      <xsl:call-template name="makeMeAPersName">
        <xsl:with-param name="type" select="ancestor::tei:persName/@type"/>
      </xsl:call-template>
    </xsl:for-each>
  </xsl:template>
  
  <!--<xsl:template match="tei:abbr|tei:expan|tei:sic|tei:corr|tei:orig|tei:reg"
    mode="makemeapersname">
    <persName type="{local-name(.)}"><xsl:apply-templates/></persName>
  </xsl:template>-->
  <xsl:template name="makeMeAPersName">
    <xsl:param name="type"/>
    <persName type="{local-name(.)}">
      <xsl:if test="$type">
        <xsl:attribute name="data-tapas-type" select="$type"/>
      </xsl:if>
      <xsl:apply-templates/>
    </persName>
  </xsl:template>
  
  <!-- ************************ -->
  <!-- data processing routines -->
  <!-- ************************ -->
  
  <xsl:template name="handle_ptrs" match="@target|@url|@ref|@corresp|@facs">
    <!-- Note 1: list of attrs matched should be extracted from -->
    <!-- schema or ODD. But I don't have time for that right -->
    <!-- now, so we just match those that show up in profiling -->
    <!-- data we received. -->
    <xsl:variable name="ptr" select="normalize-space(.)"/>
    <!-- Retain original: -->
    <xsl:copy>
      <xsl:value-of select="$ptr"/>
    </xsl:copy>
    <xsl:variable name="myself">
      <!--<xsl:value-of select="replace($ptr,'file:','')"/>-->
      <xsl:choose>
        <xsl:when test="starts-with( $ptr,'file:/')">
          <xsl:value-of select="substring-after( $ptr,':')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$ptr"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="onNet">
      <xsl:value-of select="
        (  starts-with( $myself,'http://' )
        or starts-with( $myself,'https://')
        or starts-with( $myself,'ftp://'  ) )
        "/>
    </xsl:variable>
    <!-- Note 2: we simply don't support pointer attributes with -->
    <!-- more than one URI in the value. See e-mail of 2014-06-19 16:14. -->
    <xsl:if test="contains( $ptr,' ')">
      <xsl:message>
        <xsl:text>multiple URIs in value "</xsl:text>
        <xsl:value-of select="$ptr"/>
        <xsl:text>" of attribute </xsl:text>
        <xsl:value-of select="name()"/>
      </xsl:message>
      <xsl:attribute name="data-tapas-{name(.)}-warning">
        <xsl:text>multiple URIs in value</xsl:text>
      </xsl:attribute>
    </xsl:if>
    <!-- Determine whether to generate a TAPAS-friendly path. -->
    <xsl:choose>
      <xsl:when test="starts-with( $myself,'#')">
        <!-- points to internal XML element -->
        <xsl:variable name="bare-name" select="substring( $myself, 2 )"/>
        <xsl:choose>
          <xsl:when test="id( $bare-name )">
            <!-- points to an existing internal XML element -->
            <!-- current attr will do unless we're an @facs -->
            <!-- that points to a <surface> -->
            <xsl:if test="local-name()='facs'  and  id( $bare-name )[self::tei:surface]">
              <xsl:message>DEBUG: do right by facs!</xsl:message>
            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <!-- points to non-existent internal XML element -->
            <xsl:attribute name="data-tapas-{name(.)}-warning">
              <xsl:text>target not found</xsl:text>
            </xsl:attribute>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="$onNet='true'  and  contains( $myself,'#')">
        <!-- points to a web document fragment; XML? -->
        <!-- for now, current attr will have to do -->
      </xsl:when>
      <xsl:when test="$onNet='true'">
        <!-- points to a complete web document -->
        <!-- current attr will do -->
      </xsl:when>
      <xsl:when test="contains( $myself,'#')">
        <!-- points to a document fragment; XML? -->
        <!-- generate a local pointer, depending on later-->
        <!-- routines to suck in the data -->
        <xsl:call-template name="maybe-flatten">
          <xsl:with-param name="me" select="$myself"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains( $myself,'/')">
        <!-- path to a local file -->
        <xsl:call-template name="maybe-flatten">
          <xsl:with-param name="me" select="$myself"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <!-- just a local file -->
        <xsl:call-template name="maybe-flatten">
          <xsl:with-param name="me" select="$myself"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- *************************** -->
  <!-- data processing subroutines -->
  <!-- *************************** -->
  
  <xsl:template name="remove-path-component">
    <xsl:param name="target" required="yes"/>
    <xsl:variable name="url">
      <xsl:choose>
        <xsl:when test="contains($target,'#')">
          <xsl:value-of select="substring-before($target,'#')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$target"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="url-sans-path">
      <xsl:choose>
        <xsl:when test="contains( $url,'/')">
          <xsl:call-template name="remove-path-component">
            <xsl:with-param name="target" select="substring-after( $url,'/')"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$url"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!-- Return the flattened URI. -->
    <xsl:value-of select="$url-sans-path"/>
    <xsl:if test="contains($target,'#')">
      <xsl:text>#</xsl:text>
      <xsl:value-of select="substring-after($target,'#')"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="maybe-flatten">
    <xsl:param name="me" required="yes"/>
    <xsl:variable name="flattened">
      <xsl:call-template name="remove-path-component">
        <xsl:with-param name="target" select="$me"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="newpath">
      <xsl:if test="not(matches($flattened,'.(jpg | jp2 | jpeg | gif | png | tif | tiff)$','i'))">
        <xsl:text>../support/</xsl:text>
      </xsl:if>
      <xsl:value-of select="$flattened"/>
    </xsl:variable>
    <xsl:if test="$newpath != $me">
      <xsl:attribute name="data-tapas-flattened-{name(.)}" select="$newpath"/>
      <xsl:message>DEBUG: <xsl:value-of select="$newpath"/> != <xsl:value-of select="$me"/>?</xsl:message>
    </xsl:if>
  </xsl:template>
  
</xsl:stylesheet>